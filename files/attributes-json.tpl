{
  "delivery-cluster": {
    "delivery": {
      "accept_license": ${license},
      "chef_server": "https://${chef_fqdn}/organizations/${chef_org}",
      "fqdn": "${host}.${domain}",
      "version": "${version}"
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
