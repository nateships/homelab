# Supplied as TF_VAR_k8s_vlan_cidr by the homelab context (admin stack).
variable "k8s_vlan_cidr" {
  description = "k8s VLAN CIDR the PVE host advertises to the tailnet"
  type        = string
}
