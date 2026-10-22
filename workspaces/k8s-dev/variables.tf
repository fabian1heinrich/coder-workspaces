variable "namespace" {
  type        = string
  description = "Existing Kubernetes namespace in which workspace resources are created."
  default     = "coder"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "namespace must be a DNS label."
  }
}

variable "workspace_image" {
  type        = string
  description = "Repository-owned Kubernetes operations workspace image, pinned by sha256 digest."

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.workspace_image))
    error_message = "workspace_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "code_server_image" {
  type        = string
  description = "GHCR code-server image-volume payload, pinned by sha256 digest."
  default     = "ghcr.io/fabian1heinrich/coder-workspaces/code-server:0.1.0@sha256:8405424b2479f19052945ee65376fbbfabd97e1ac04bb9fabaf963074cb2cdf8"

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.code_server_image))
    error_message = "code_server_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "vsix_image" {
  type        = string
  description = "Repository-owned Kubernetes VSIX image-volume payload, pinned by sha256 digest."

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.vsix_image))
    error_message = "vsix_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "home_storage_class" {
  type        = string
  description = "StorageClass for persistent workspace homes; empty selects the cluster default."
  default     = ""

  validation {
    condition     = var.home_storage_class == "" || can(regex("^[a-z0-9]([-a-z0-9./]*[a-z0-9])?$", var.home_storage_class))
    error_message = "home_storage_class must be empty or a StorageClass name."
  }
}

variable "git_auth_mode" {
  type        = string
  description = "Git authentication mode: anonymous, secret, or external-auth."
  default     = "external-auth"

  validation {
    condition     = contains(["anonymous", "secret", "external-auth"], var.git_auth_mode)
    error_message = "git_auth_mode must be anonymous, secret, or external-auth."
  }
}

variable "git_credentials_secret_name" {
  type        = string
  description = "Secret containing username and password keys when git_auth_mode is secret."
  default     = ""

  validation {
    condition     = var.git_credentials_secret_name == "" || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.git_credentials_secret_name))
    error_message = "git_credentials_secret_name must be empty or a DNS label."
  }
}

variable "image_pull_secret_name" {
  type        = string
  description = "Optional image pull Secret used by workspace Pods."
  default     = "private-registry"

  validation {
    condition     = var.image_pull_secret_name == "" || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.image_pull_secret_name))
    error_message = "image_pull_secret_name must be empty or a DNS label."
  }
}

variable "git_base_url" {
  type        = string
  description = "Base URL of the Git service used by workspace repositories."
  default     = ""

  validation {
    condition     = var.git_base_url == "" || can(regex("^https?://[^[:space:]/]+(:[0-9]+)?$", var.git_base_url))
    error_message = "git_base_url must be empty or an HTTP(S) origin without a trailing slash."
  }
}

variable "git_external_auth_id" {
  type        = string
  description = "Coder external-auth provider ID used when git_auth_mode is external-auth."
  default     = "forgejo"
}

variable "platform_ca_config_map_name" {
  type        = string
  description = "Optional ConfigMap containing platform-root-ca.pem for internal HTTPS."
  default     = ""

  validation {
    condition     = var.platform_ca_config_map_name == "" || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.platform_ca_config_map_name))
    error_message = "platform_ca_config_map_name must be empty or a DNS label."
  }
}

variable "default_repository" {
  type        = string
  description = "Default owner/repository path in the configured Git service."
  default     = ""

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.default_repository))
    error_message = "default_repository must be empty or an owner/repository path."
  }
}

variable "default_git_branch" {
  type        = string
  description = "Default repository branch or revision."
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.default_git_branch))
    error_message = "default_git_branch contains unsupported characters."
  }
}
