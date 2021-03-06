tf_chef_delivery CHANGELOG
==========================

This file is used to list changes made in each version of the Terraform plan.

v1.0.0 (2016-05-02)
-------------------
- [Brian Menges] - Add `accept_license` to handle Chef MLSA
- [Brian Menges] - Add `delivery_version` to install specific Delivery version. Default: `latest`
- [Brian Menges] - Add `root_volume_size` and `root_volume_type` variables to handle larger than default root volumes

v0.3.9 (2016-04-26)
-------------------
- [Brian Menges] - Missing double quote in delivery credentials file write resource

v0.3.8 (2016-04-26)
-------------------
- [Brian Menges] - Source data bag files contained trailing newline, using tr to remove

v0.3.7 (2016-04-26)
-------------------
- [Brian Menges] - Fix unterminated line in [outputs.tf](outputs.tf)

v0.3.6 (2016-04-26)
-------------------
- [Brian Menges] - Remove delivery data bag, leave keys data bag
- [Brian Menges] - Improve scripting and sed magic
- [Brian Menges] - Replace `credentials` with `credentials_file` in [outputs.tf](outputs.tf)

v0.3.5 (2016-04-25)
-------------------
- [Brian Menges] - Use `client_version`

v0.3.4 (2016-04-25)
-------------------
- [Brian Menges] - Can't set permissions to user that doesn't exist

v0.3.3 (2016-04-25)
-------------------
- [Brian Menges] - Add AWS provisioner

v0.3.2 (2016-04-25)
-------------------
- [Brian Menges] - Merge error, trying v0.3.1 again

v0.3.1 (2016-04-25)
-------------------
- [Brian Menges] - Add outputs `private_ip` and `public_ip`

v0.3.0 (2016-04-25)
-------------------
- [Brian Menges] - Documentation updates
- [Brian Menges] - Implemented `wait_on` dependency chain usage
- [Brian Menges] - Added variables `wait_on`, `log_to_file`, `public_ip`, `root_delete_termination`, `client_version`
- [Brian Menges] - Updated `main.tf` to use new variables
- [Brian Menges] - Updated HEREDOC style usage in plan
- [Brian Menges] - Updated `attributes-json.tpl` and added chef_client
- [Brian Menges] - Specify provider so that defaults can be overwritten

v0.2.2 (2016-03-23)
-------------------
- [Brian Menges] - Added handle for internal DNS on Route53
- [Brian Menges] - Added tag to aws_instance

v0.2.1 (2016-03-21)
-------------------
- [Brian Menges] - Code consistency update; align with other TF modules
- [Brian Menges] - Re-ordered several variables (alphabetize)
- [Brian Menges] - Update some comment lines
- [Brian Menges] - Fix databag issue (forgot to upload after creating)

v0.2.0 (2016-03-21)
-------------------
- [Brian Menges] - Re-wrote most of the code
- [Brian Menges] - Some formatting to make reading easier
- [Brian Menges] - Syntax updates for Terraform 0.6.14
- [Brian Menges] - Add Route53 controls
- [Brian Menges] - Add SSL certificate controls
- [Brian Menges] - Replace hostname computation from basename and count to just hostname and domain
- [Brian Menges] - Implement user and AMI mapping per [tf_chef_server](https://github.com/mengesb/tf_chef_server)
- [Brian Menges] - Remove specific IPTables handles, disabling IPTables or UFW globally
- [Brian Menges] - Better handle on delivery and keys databags
- [Brian Menges] - Provisioning using Chef provisioner and attributes_json
- [Brian Menges] - Using cookbooks at Chef server to govern system settings better than scripting EC2 variable hooks
- [Brian Menges] - Using templates instead of all HEREDOC
- [Brian Menges] - Doc and version updates

v0.1.5 (2016-02-16)
-------------------
- [Brian Menges] - Trimmed down some of the commands executed
- [Brian Menges] - Ordering
- [Brian Menges] - Broke down one long remote-exec to several based on task
- [Brian Menges] - Put only the files necessary where they need to go

v0.1.4 (2016-02-15)
-------------------
- [Brian Menges] - Putting it all back
- [Brian Menges] - Fixed the real problem; sourcing the right file!
- [Brian Menges] - Need to copy in delivery.pem to /etc/delivery still (cookbook requirement)

v0.1.3 (2016-02-15)
-------------------
- [Brian Menges] - Breaking out key generation

v0.1.2 (2016-02-15)
-------------------
- [Brian Menges] - Documentation cleanup and consisteny with other tf_chef works
- [Brian Menges] - More control around delivery user creation
- [Brian Menges] - Reordered some things
- [Brian Menges] - shortened some variables
- [Brian Menges] - Adjustments required as a result of tf_chef_server updates

v0.1.1 (2016-02-14)
-------------------
- [Brian Menges] - Fixing databag issues
- [Brian Menges] - Remove org from name tag
- [Brian Menges] - Adding security group rules between server and delivery

v0.1.0 (2016-02-11)
-------------------
- [Brian Menges] - Made delivery less directly dependent on tf_chef_server
- [Brian Menges] - Working now with encrpyted data bag 'keys' for builders (may move this)
- [Brian Menges] - Handles 'delivery' user creation @ chef server
- [Brian Menges] - Variable changes

v0.0.1 (2016-02-05)
-------------------
- [Brian Menges] - Create repo

- - -
Check the [Markdown Syntax Guide](http://daringfireball.net/projects/markdown/syntax) for help with Markdown.

The [Github Flavored Markdown page](http://github.github.com/github-flavored-markdown/) describes the differences between markdown on github and standard markdown.

