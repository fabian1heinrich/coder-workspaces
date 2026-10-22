variable "start_count" {
  type        = number
  description = "1 while the workspace is started, 0 while it is stopped. The persistent home claim is kept in both states."

  validation {
    condition     = contains([0, 1], var.start_count)
    error_message = "start_count must be 0 or 1."
  }
}

variable "namespace" {
  type        = string
  description = "Existing Kubernetes namespace in which workspace resources are created."

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "namespace must be a DNS label."
  }
}

variable "deployment_name" {
  type        = string
  description = "Name of the workspace Deployment."
}

variable "home_claim_name" {
  type        = string
  description = "Name of the persistent home PersistentVolumeClaim."
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to the Deployment, its Pods, and the home claim."
}

variable "selector_labels" {
  type        = map(string)
  description = "Immutable Deployment selector labels. They must carry only stable workspace identity."
}

variable "owner_email" {
  type        = string
  description = "Workspace owner's email address, recorded as an annotation."
}

variable "home_storage_class" {
  type        = string
  description = "StorageClass for the persistent home; empty selects the cluster default."
  default     = ""
}

variable "home_storage_size" {
  type        = string
  description = "Requested size of the persistent home, such as 20Gi."

  validation {
    condition     = can(regex("^[0-9]+(Ki|Mi|Gi|Ti)$", var.home_storage_size))
    error_message = "home_storage_size must be a binary Kubernetes quantity, such as 20Gi."
  }
}

variable "workspace_image" {
  type        = string
  description = "Workspace runtime image, pinned by sha256 digest."

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.workspace_image))
    error_message = "workspace_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "code_server_image" {
  type        = string
  description = "code-server image-volume payload mounted read-only at /opt/code-server, pinned by sha256 digest."

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.code_server_image))
    error_message = "code_server_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "vsix_image" {
  type        = string
  description = "Approved VSIX image-volume payload mounted read-only at /opt/vsix, pinned by sha256 digest."

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.vsix_image))
    error_message = "vsix_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "image_pull_secret_name" {
  type        = string
  description = "Optional image pull Secret used by the workspace Pod."
  default     = ""
}

variable "cpu" {
  type        = string
  description = "CPU request and limit, which intentionally match."
}

variable "memory" {
  type        = string
  description = "Memory request and limit, which intentionally match."
}

variable "ephemeral_storage_request" {
  type        = string
  description = "Ephemeral storage request for the workspace container."
  default     = "2Gi"
}

variable "ephemeral_storage_limit" {
  type        = string
  description = "Ephemeral storage limit for the workspace container."
  default     = "10Gi"
}

variable "tmp_size_limit" {
  type        = string
  description = "Size limit of the /tmp emptyDir."
  default     = "4Gi"
}

variable "read_only_root_filesystem" {
  type        = bool
  description = "Mount the container root filesystem read-only. Runtimes that write outside /home/coder and /tmp must set this to false."
  default     = true
}

variable "platform_ca_config_map_name" {
  type        = string
  description = "Optional ConfigMap containing platform-root-ca.pem for internal HTTPS."
  default     = ""
}

variable "git_auth_mode" {
  type        = string
  description = "Git authentication mode: anonymous, secret, or external-auth."
  default     = "anonymous"

  validation {
    condition     = contains(["anonymous", "secret", "external-auth"], var.git_auth_mode)
    error_message = "git_auth_mode must be anonymous, secret, or external-auth."
  }
}

variable "git_base_url" {
  type        = string
  description = "Base URL used to scope HTTP Git credentials."
  default     = ""
}

variable "git_credentials_secret_name" {
  type        = string
  description = "Secret containing username and password keys for HTTP Git authentication."
  default     = ""
}

variable "startup_commands" {
  type        = list(string)
  description = "Commands from the workspace image that run, in order, before the agent starts."
  default     = []
}

variable "agent_init_script" {
  type        = string
  description = "Coder agent init script, which runs last and does not return."
}

variable "agent_token" {
  type        = string
  description = "Coder agent token."
  sensitive   = true
}

variable "environment" {
  type        = any
  description = "Additional container environment entries, each a Kubernetes EnvVar object."
  default     = []
}
