variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default = "udacity-demo2"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "West Europe"
}

variable "tags" {
  description = "A list of default tags"
  type = map
  default = {
    environment = "dev"
  }
}

variable "vm_count" {
  description = "Create this amount of virtual machines into the resource group"
  default = 2
  type = number
}

variable "image_name" {
  description = "Internal image id to use e.g. created by packer earlier"
  default = "/subscriptions/<subscription-id>/resourceGroups/udacity-demo2-rg/providers/Microsoft.Compute/images/packer-ubuntu-18.04-lts"
  sensitive = true
}

variable "vm_username" {
  description = "Default VM username"
  default = "AzureUser"
}

variable "vm_password" {
  description = "Default VM user's password"
  default = "Very.Secure139"
  sensitive = true
}

variable "lb_probes" {
  description = "Define a list of load balancer probes to test"
  type = map
  default = {
    "http" = 80
  }
}

variable "lb_rules" {
  description = "Define a list of load balancer rules"
  type = list(object({
    name = string
    protocol = string
    port_frontend = number
    port_backend = number
  }))
  default = [
    {
      name = "HttpRule"
      protocol = "TCP"
      port_frontend = 80
      port_backend = 80
    }
  ]
}
