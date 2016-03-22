{
  "delivery-cluster": {
    "delivery": {
      "chef_server": "https://${chef_fqdn}/organizations/${chef_org}",
      "fqdn": "${host}.${domain}"
    }
  },
  "fqdn": "${host}.${domain}",
  "firewall": {
    "allow_established": true,
    "allow_ssh": true
  },
  "system": {
    "short_hostname": "${host}",
    "domain_name": "${domain}",
    "manage_hostsfile": true
  },
  "tags": []
}
