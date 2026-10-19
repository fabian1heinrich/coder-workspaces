# kubernetes_deployment_v1 does not expose the ImageVolumeSource schema in the
# pinned provider. kubernetes_manifest uses the target cluster's OpenAPI schema
# for the read-only code-server and VSIX OCI image volumes.
resource "kubernetes_manifest" "workspace" {
  count = data.coder_workspace.me.start_count

  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name        = local.deployment_name
      namespace   = var.namespace
      labels      = local.labels
      annotations = { "com.coder.user.email" = data.coder_workspace_owner.me.email }
    }
    spec = {
      replicas                = 1
      revisionHistoryLimit    = 1
      progressDeadlineSeconds = 300
      selector = {
        matchLabels = local.labels
      }
      strategy = {
        type = "Recreate"
      }
      template = {
        metadata = {
          labels = local.labels
        }
        spec = {
          automountServiceAccountToken = true
          serviceAccountName           = var.kubernetes_service_account_name
          enableServiceLinks           = false
          imagePullSecrets             = var.image_pull_secret_name == "" ? [] : [{ name = var.image_pull_secret_name }]
          securityContext = {
            runAsUser           = 1000
            runAsGroup          = 1000
            runAsNonRoot        = true
            fsGroup             = 1000
            fsGroupChangePolicy = "OnRootMismatch"
            seccompProfile      = { type = "RuntimeDefault" }
          }
          containers = [
            {
              name            = "dev"
              image           = var.workspace_image
              imagePullPolicy = "IfNotPresent"
              command = ["sh", "-c", <<-EOT
                set -eu
                if [ -n "$${ZARF_GIT_USERNAME:-}" ]; then
                  credential_dir="$${HOME}/.config/zarf-git"
                  credential_helper="$${credential_dir}/credential-helper"
                  mkdir -p "$${credential_dir}"
                  printf '%s\n' \
                    '#!/bin/sh' \
                    '[ "$1" = get ] || exit 0' \
                    'printf "username=%s\\npassword=%s\\n" "$ZARF_GIT_USERNAME" "$ZARF_GIT_PASSWORD"' \
                    > "$${credential_helper}"
                  chmod 0700 "$${credential_helper}"
                  git config --global --replace-all \
                    'credential.${var.git_base_url}.helper' \
                    "$${credential_helper}"

                  legacy_askpass="$${credential_dir}/askpass"
                  if [ "$(git config --global --get core.askPass || true)" = "$${legacy_askpass}" ]; then
                    git config --global --unset-all core.askPass
                  fi
                fi

                kubeconfig="$${HOME}/.kube/coder-in-cluster"
                umask 077
                mkdir -p "$${HOME}/.kube"
                chmod 0700 "$${HOME}/.kube"
                cat > "$${kubeconfig}.tmp" <<'KUBECONFIG'
                apiVersion: v1
                kind: Config
                clusters:
                  - name: in-cluster
                    cluster:
                      certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                      server: https://kubernetes.default.svc
                contexts:
                  - name: in-cluster
                    context:
                      cluster: in-cluster
                      namespace: ${var.kubernetes_target_namespace}
                      user: workspace
                current-context: in-cluster
                users:
                  - name: workspace
                    user:
                      tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
                KUBECONFIG
                mv "$${kubeconfig}.tmp" "$${kubeconfig}"

                extensions_dir="$${HOME}/.local/share/code-server/extensions"
                mkdir -p "$${extensions_dir}"
                for extension in /opt/vsix/*.vsix; do
                  [ -e "$${extension}" ] || continue
                  /opt/vscode-server/bin/code-server \
                    --extensions-dir="$${extensions_dir}" \
                    --force \
                    --install-extension "$${extension}"
                done

                ${coder_agent.main.init_script}
              EOT
              ]
              env = concat(
                [
                  {
                    name  = "CODER_AGENT_TOKEN"
                    value = coder_agent.main.token
                  },
                  {
                    name  = "CODER_AGENT_DEVCONTAINERS_ENABLE"
                    value = "false"
                  },
                  {
                    name  = "HOME"
                    value = "/home/coder"
                  },
                  {
                    name  = "SHELL"
                    value = "/usr/bin/zsh"
                  },
                  {
                    name  = "KUBECONFIG"
                    value = "/home/coder/.kube/coder-in-cluster"
                  },
                  {
                    name = "EXTENSIONS_GALLERY"
                    value = jsonencode({
                      serviceUrl          = "http://127.0.0.1:9"
                      itemUrl             = "http://127.0.0.1:9"
                      resourceUrlTemplate = "http://127.0.0.1:9/{publisher}/{name}/{version}/{path}"
                    })
                  },
                ],
                local.git_environment,
                var.platform_ca_config_map_name == "" ? [] : [
                  {
                    name  = "GIT_SSL_CAINFO"
                    value = "/etc/coder/ca/platform-root-ca.pem"
                  },
                  {
                    name  = "SSL_CERT_FILE"
                    value = "/etc/coder/ca/platform-root-ca.pem"
                  },
                ],
              )
              resources = {
                requests = {
                  cpu                 = local.cpu_limit
                  memory              = local.memory_limit
                  "ephemeral-storage" = local.ephemeral_storage_request
                }
                limits = {
                  cpu                 = local.cpu_limit
                  memory              = local.memory_limit
                  "ephemeral-storage" = local.ephemeral_storage_limit
                }
              }
              securityContext = {
                allowPrivilegeEscalation = false
                capabilities             = { drop = ["ALL"] }
                readOnlyRootFilesystem   = true
                runAsNonRoot             = true
                runAsUser                = 1000
                runAsGroup               = 1000
                seccompProfile           = { type = "RuntimeDefault" }
              }
              volumeMounts = concat(
                [
                  {
                    name      = "home"
                    mountPath = "/home/coder"
                  },
                  {
                    name      = "vscode-server"
                    mountPath = "/opt/vscode-server"
                    readOnly  = true
                  },
                  {
                    name      = "vsix"
                    mountPath = "/opt/vsix"
                    readOnly  = true
                  },
                  {
                    name      = "tmp"
                    mountPath = "/tmp"
                  },
                ],
                var.platform_ca_config_map_name == "" ? [] : [
                  {
                    name      = "platform-root-ca"
                    mountPath = "/etc/coder/ca"
                    readOnly  = true
                  },
                ],
              )
            },
          ]
          volumes = concat(
            [
              {
                name = "home"
                persistentVolumeClaim = {
                  claimName = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
                }
              },
              {
                name = "vscode-server"
                image = {
                  reference  = var.code_server_image
                  pullPolicy = "IfNotPresent"
                }
              },
              {
                name = "vsix"
                image = {
                  reference  = var.vsix_image
                  pullPolicy = "IfNotPresent"
                }
              },
              {
                name = "tmp"
                emptyDir = {
                  sizeLimit = local.tmp_size_limit
                }
              },
            ],
            var.platform_ca_config_map_name == "" ? [] : [
              {
                name = "platform-root-ca"
                configMap = {
                  name = var.platform_ca_config_map_name
                }
              },
            ],
          )
          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 1
                  podAffinityTerm = {
                    topologyKey = "kubernetes.io/hostname"
                    labelSelector = {
                      matchExpressions = [
                        {
                          key      = "app.kubernetes.io/name"
                          operator = "In"
                          values   = ["coder-workspace"]
                        },
                      ]
                    }
                  }
                },
              ]
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_persistent_volume_claim_v1.home]
}
