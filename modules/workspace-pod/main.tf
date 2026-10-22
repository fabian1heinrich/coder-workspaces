# The workspace Pod and its persistent home, shared by every template in this
# repository so that the pod security contract, the read-only OCI image
# volumes, and the persistence boundary are defined exactly once.
#
# kubernetes_deployment_v1 does not expose the ImageVolumeSource schema in the
# pinned provider. kubernetes_manifest uses the target cluster's OpenAPI schema
# instead, which allows read-only OCI image volumes without init-container
# copies.

locals {
  # Platform payloads are mounted read-only; only /home/coder and /tmp are
  # writable, which is what keeps user state separable from platform state.
  base_volume_mounts = [
    {
      name      = "home"
      mountPath = "/home/coder"
    },
    {
      name      = "code-server"
      mountPath = "/opt/code-server"
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
  ]

  ca_volume_mounts = var.platform_ca_config_map_name == "" ? [] : [
    {
      name      = "platform-root-ca"
      mountPath = "/etc/coder/ca"
      readOnly  = true
    },
  ]

  base_volumes = [
    {
      name = "home"
      persistentVolumeClaim = {
        claimName = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
      }
    },
    {
      name = "code-server"
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
        sizeLimit = var.tmp_size_limit
      }
    },
  ]

  ca_volumes = var.platform_ca_config_map_name == "" ? [] : [
    {
      name = "platform-root-ca"
      configMap = {
        name = var.platform_ca_config_map_name
      }
    },
  ]

  base_environment = concat(
    [
      # Coder supplies the agent token as a plain environment value. Anyone
      # able to read workspace Pods in this namespace can use it, so keep
      # namespace read access restricted.
      {
        name  = "CODER_AGENT_TOKEN"
        value = var.agent_token
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
      # An unroutable gallery keeps code-server from reaching a marketplace; the
      # approved set arrives through the /opt/vsix image volume instead.
      {
        name = "EXTENSIONS_GALLERY"
        value = jsonencode({
          serviceUrl          = "http://127.0.0.1:9"
          itemUrl             = "http://127.0.0.1:9"
          resourceUrlTemplate = "http://127.0.0.1:9/{publisher}/{name}/{version}/{path}"
        })
      },
    ],
    # Git documents !-prefixed shell helpers as the container-friendly way to
    # consume credentials from environment variables without writing to disk.
    var.git_auth_mode == "secret" ? [
      {
        name  = "GIT_CONFIG_COUNT"
        value = "1"
      },
      {
        name  = "GIT_CONFIG_KEY_0"
        value = "credential.${var.git_base_url}.helper"
      },
      {
        name  = "GIT_CONFIG_VALUE_0"
        value = "!f() { [ \"$1\" != get ] || printf 'username=%s\\npassword=%s\\n' \"$WORKSPACE_GIT_USERNAME\" \"$WORKSPACE_GIT_PASSWORD\"; }; f"
      },
      {
        name = "WORKSPACE_GIT_USERNAME"
        valueFrom = {
          secretKeyRef = {
            name = var.git_credentials_secret_name
            key  = "username"
          }
        }
      },
      {
        name = "WORKSPACE_GIT_PASSWORD"
        valueFrom = {
          secretKeyRef = {
            name = var.git_credentials_secret_name
            key  = "password"
          }
        }
      },
    ] : [],
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

  container_security_context = merge(
    {
      allowPrivilegeEscalation = false
      capabilities             = { drop = ["ALL"] }
      runAsNonRoot             = true
      runAsUser                = 1000
      runAsGroup               = 1000
      seccompProfile           = { type = "RuntimeDefault" }
    },
    var.read_only_root_filesystem ? { readOnlyRootFilesystem = true } : {},
  )

  # Startup commands come from the workspace image. The agent init script runs
  # last because it does not return.
  command_script = join("\n", concat(["set -eu"], var.startup_commands, [var.agent_init_script]))
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = var.home_claim_name
    namespace = var.namespace
    labels    = var.labels
    annotations = {
      "com.coder.user.email" = var.owner_email
    }
  }

  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.home_storage_class == "" ? null : var.home_storage_class

    resources {
      requests = {
        storage = var.home_storage_size
      }
    }
  }
}

resource "kubernetes_manifest" "workspace" {
  count = var.start_count

  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name        = var.deployment_name
      namespace   = var.namespace
      labels      = var.labels
      annotations = { "com.coder.user.email" = var.owner_email }
    }
    spec = {
      replicas                = 1
      revisionHistoryLimit    = 1
      progressDeadlineSeconds = 300
      selector = {
        matchLabels = var.selector_labels
      }
      strategy = {
        type = "Recreate"
      }
      template = {
        metadata = {
          labels = var.labels
        }
        spec = {
          automountServiceAccountToken = false
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
              command         = ["sh", "-c", local.command_script]
              env             = concat(local.base_environment, var.environment)
              resources = {
                requests = {
                  cpu                 = var.cpu
                  memory              = var.memory
                  "ephemeral-storage" = var.ephemeral_storage_request
                }
                limits = {
                  cpu                 = var.cpu
                  memory              = var.memory
                  "ephemeral-storage" = var.ephemeral_storage_limit
                }
              }
              securityContext = local.container_security_context
              volumeMounts    = concat(local.base_volume_mounts, local.ca_volume_mounts)
            },
          ]
          volumes = concat(local.base_volumes, local.ca_volumes)
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
