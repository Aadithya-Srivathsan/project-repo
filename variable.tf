variable "location" {
  type        = string
  description = "Azure region"
  default     = "westeurope"
}

variable "project_name" {
  type        = string
  description = "Project short name used in resource names"
  default     = "gptwebfunc"
}

variable "azure_openai_endpoint" {
  type        = string
  description = "Azure OpenAI endpoint (https://xxxx.openai.azure.com)"
}

variable "azure_openai_api_key" {
  type        = string
  description = "Azure OpenAI API key"
  sensitive   = true
}

variable "azure_openai_deployment" {
  type        = string
  description = "Azure OpenAI deployment name (model deployment)"
}

variable "azure_openai_api_version" {
  type        = string
  description = "Azure OpenAI API version"
  default     = "2025-03-01-preview"
}
