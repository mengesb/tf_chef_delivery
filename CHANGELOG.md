v0.1.5 (2016-02-16)
-------------------
- Trimmed down some of the commands executed
- Ordering
- Broke down one long remote-exec to several based on task
- Put only the files necessary where they need to go

v0.1.4 (2016-02-15)
-------------------
- Putting it all back
- Fixed the real problem; sourcing the right file!
- Need to copy in delivery.pem to /etc/delivery still (cookbook requirement)

v0.1.3 (2016-02-15)
-------------------
- Breaking out key generation

v0.1.2 (2016-02-15)
-------------------
- Documentation cleanup and consisteny with other tf_chef works
- More control around delivery user creation
- Reordered some things
- shortened some variables
- Adjustments required as a result of tf_chef_server updates

v0.1.1 (2016-02-14)
-------------------
- Fixing databag issues
- Remove org from name tag
- Adding security group rules between server and delivery

v0.1.0 (2016-02-11)
-------------------
- Made delivery less directly dependent on tf_chef_server
- Working now with encrpyted data bag 'keys' for builders (may move this)
- Handles 'delivery' user creation @ chef server
- Variable changes

v0.0.1 (2016-02-05)
-------------------
- Create repo
