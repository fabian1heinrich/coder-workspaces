variable "namespace" {
  type        = string
  description = "Existing Kubernetes namespace in which workspace resources are created."
  default     = "coder"
}

variable "sandbox_image" {
  type        = string
  description = "Default Python sandbox runtime in the deployment-owned registry, pinned by sha256 digest."
  default     = "ghcr.io/fabian1heinrich/coder-workspaces/python-workspace:0.1.0@sha256:9da7db38010f8fca3b97436aada761112856cdf2631ceede34efbce30f985266"

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.sandbox_image))
    error_message = "sandbox_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "deja_doc_image" {
  type        = string
  description = "Optional deja-doc workspace image, pinned by sha256 digest. Empty disables the project."
  default     = ""

  validation {
    condition     = var.deja_doc_image == "" || can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.deja_doc_image))
    error_message = "deja_doc_image must be empty or pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "deja_doc_repository" {
  type        = string
  description = "Default owner/repository path for the deja-doc project."
  default     = ""

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.deja_doc_repository))
    error_message = "deja_doc_repository must be empty or an owner/repository path."
  }
}

variable "dupe_trooper_image" {
  type        = string
  description = "Optional dupe-trooper workspace image, pinned by sha256 digest. Empty disables the project."
  default     = ""

  validation {
    condition     = var.dupe_trooper_image == "" || can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.dupe_trooper_image))
    error_message = "dupe_trooper_image must be empty or pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "dupe_trooper_repository" {
  type        = string
  description = "Default owner/repository path for the dupe-trooper project."
  default     = ""

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.dupe_trooper_repository))
    error_message = "dupe_trooper_repository must be empty or an owner/repository path."
  }
}

variable "vsix_image" {
  type        = string
  description = "Default Python VSIX image-volume payload in the deployment-owned registry, pinned by sha256 digest."
  default     = "ghcr.io/fabian1heinrich/coder-workspaces/python-vsix:0.1.0@sha256:96e870317cbe15144a0d0f17ab2d8a1dc6d53dae121dc01f3d4751d62cbd628b"

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.vsix_image))
    error_message = "vsix_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "code_server_image" {
  type        = string
  description = "Default code-server image-volume payload in the deployment-owned registry, pinned by sha256 digest."
  default     = "ghcr.io/fabian1heinrich/coder-workspaces/code-server:0.1.0@sha256:8405424b2479f19052945ee65376fbbfabd97e1ac04bb9fabaf963074cb2cdf8"

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.code_server_image))
    error_message = "code_server_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "home_storage_class" {
  type        = string
  description = "StorageClass for persistent workspace homes; empty selects the cluster default."
  default     = ""
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
}

variable "sandbox_repository" {
  type        = string
  description = "Default owner/repository path for the sandbox project."
  default     = ""

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.sandbox_repository))
    error_message = "sandbox_repository must be empty or an owner/repository path."
  }
}

variable "default_git_branch" {
  type        = string
  description = "Default sandbox source revision and revision assigned to the current managed project profiles."
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.default_git_branch))
    error_message = "default_git_branch contains unsupported characters."
  }
}

variable "default_dotfiles_repository" {
  type        = string
  description = "Owner/repository path for dotfiles."
  default     = ""

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.default_dotfiles_repository))
    error_message = "default_dotfiles_repository must be empty or an owner/repository path."
  }
}

variable "default_dotfiles_branch" {
  type        = string
  description = "Default dotfiles branch."
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.default_dotfiles_branch))
    error_message = "default_dotfiles_branch contains unsupported characters."
  }
}
