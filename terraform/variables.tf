variable "azure_devops_pat" {
  description = "Azure DevOps Personal Access Token"
  sensitive   = true
}

variable "github_pat" {
  description = "GitHub Personal Access Token (with repo and workflow permissions)"
  sensitive   = true
}
