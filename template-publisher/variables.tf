variable "coder_url" {
  type        = string
  description = "URL of the Coder instance."
  default     = "http://coder.coder.svc.cluster.local"

  validation {
    condition     = can(regex("^https?://[^[:space:]]+$", var.coder_url))
    error_message = "coder_url must be an HTTP(S) URL."
  }
}

variable "coder_token" {
  type        = string
  description = "Coder session token used to publish the template."
  sensitive   = true

  validation {
    condition     = length(trimspace(var.coder_token)) > 0
    error_message = "coder_token must not be empty."
  }
}

variable "coder_namespace" {
  type        = string
  description = "Existing Kubernetes namespace in which workspace resources are created."
  default     = "coder"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.coder_namespace))
    error_message = "coder_namespace must be a DNS label."
  }
}

variable "publish_id" {
  type        = string
  description = "Optional unique suffix for publishing another revision without changing the release version."
  default     = ""

  validation {
    condition     = var.publish_id == "" || can(regex("^[a-z0-9][a-z0-9-]{0,31}$", var.publish_id))
    error_message = "publish_id must be empty or contain at most 32 lowercase letters, digits, and hyphens."
  }
}

variable "workspace_image" {
  type        = string
  description = "GHCR Python workspace runtime, pinned by sha256 digest."
  default     = "ghcr.io/fabian1heinrich/coder-workspaces/python-workspace@sha256:a350b387c888de9f18a6cb4fcb0c8372bb0496a0d8abd2e57cd8de968b29ef74"

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.workspace_image))
    error_message = "workspace_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "dupe_trooper_image" {
  type        = string
  description = "Optional dupe-trooper workspace image, pinned by sha256 digest."
  default     = ""

  validation {
    condition     = var.dupe_trooper_image == "" || can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.dupe_trooper_image))
    error_message = "dupe_trooper_image must be empty or pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "deja_doc_image" {
  type        = string
  description = "Optional deja-doc workspace image, pinned by sha256 digest."
  default     = ""

  validation {
    condition     = var.deja_doc_image == "" || can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.deja_doc_image))
    error_message = "deja_doc_image must be empty or pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "vsix_image" {
  type        = string
  description = "GHCR Python VSIX image-volume payload, pinned by sha256 digest."
  default     = "ghcr.io/fabian1heinrich/coder-workspaces/python-vsix@sha256:b97eae31de6a9d6b33aed45db57870680dbdf827d92647b8880aa66d6db8a47d"

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.vsix_image))
    error_message = "vsix_image must be pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "code_server_image" {
  type        = string
  description = "GHCR code-server image-volume payload, pinned by sha256 digest."
  default     = "ghcr.io/fabian1heinrich/coder-workspaces/code-server@sha256:a92b84f1440bb110f807f28891e678ad326022a2f39545a9534e62308f9625d4"

  validation {
    condition     = can(regex("^[^[:space:]@]+@sha256:[0-9a-f]{64}$", var.code_server_image))
    error_message = "code_server_image must be an OCI reference pinned with @sha256:<64 lowercase hex characters>."
  }
}

variable "home_storage_class" {
  type        = string
  description = "StorageClass for persistent workspace homes; an empty value uses the cluster default."
  default     = ""

  validation {
    condition     = var.home_storage_class == "" || can(regex("^[a-z0-9]([-a-z0-9./]*[a-z0-9])?$", var.home_storage_class))
    error_message = "home_storage_class must be empty or a StorageClass name."
  }
}

variable "git_secret_name" {
  type        = string
  description = "Secret containing username and password keys for the internal Zarf Gitea service."
  default     = "private-git-server"

  validation {
    condition     = var.git_secret_name == "" || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.git_secret_name))
    error_message = "git_secret_name must be empty or a DNS label."
  }
}

variable "image_pull_secret_name" {
  type        = string
  description = "Optional image pull Secret used by workspace Pods."
  default     = ""

  validation {
    condition     = var.image_pull_secret_name == "" || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.image_pull_secret_name))
    error_message = "image_pull_secret_name must be empty or a DNS label."
  }
}

variable "git_base_url" {
  type        = string
  description = "Base URL of the Git service used by workspace repositories."
  default     = "http://zarf-gitea-http.zarf.svc.cluster.local:3000"

  validation {
    condition     = can(regex("^https?://[^[:space:]/]+(:[0-9]+)?$", var.git_base_url))
    error_message = "git_base_url must be an HTTP(S) origin without a trailing slash."
  }
}

variable "git_auth_mode" {
  type        = string
  description = "Workspace Git authentication mode: zarf-secret or external-auth."
  default     = "zarf-secret"

  validation {
    condition     = contains(["zarf-secret", "external-auth"], var.git_auth_mode)
    error_message = "git_auth_mode must be zarf-secret or external-auth."
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
  description = "Default sandbox repository and repository assigned to the current managed project profiles."
  default     = "zarf-git-user/uv-devcontainer-322178071"

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.default_repository))
    error_message = "default_repository must be empty or an owner/repository path."
  }
}

variable "default_git_branch" {
  type        = string
  description = "Default sandbox source revision and revision assigned to the current managed project profiles."
  default     = "zarf-ref-e637e71ed9bfcd2a2181c0b0c8d3050f1beb8483"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.default_git_branch))
    error_message = "default_git_branch contains unsupported characters."
  }
}

variable "default_dotfiles_repository" {
  type        = string
  description = "Owner/repository path for dotfiles in the Zarf mirror."
  default     = "zarf-git-user/coder-dotfiles-3319437223"

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.default_dotfiles_repository))
    error_message = "default_dotfiles_repository must be empty or an owner/repository path."
  }
}

variable "default_dotfiles_branch" {
  type        = string
  description = "Immutable branch for the mirrored dotfiles repository."
  default     = "zarf-ref-4d8bd9bf877c32e257f671ab30c86e898261891e"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.default_dotfiles_branch))
    error_message = "default_dotfiles_branch contains unsupported characters."
  }
}
