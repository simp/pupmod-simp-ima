[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-tpm.svg)](https://travis-ci.org/simp/pupmod-simp-ima)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with ima](#setup)
    * [What ima affects](#what-ima-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with ima](#beginning-with-the-ima-module)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)


## Description

This module manages the [Integrity Management Architecture (IMA)](https://sourceforge.net/p/linux-ima/wiki/Home/),
a tool that verifies the integrity of the system, based on filesystem 
and file hashes. The IMA class sets up IMA kernel boot flags if
they are not enabled and when they are, mounts the `securityfs`. This module can
manage the IMA policy, although modifying the policy incorrectly could cause
your system to become read-only.


### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://github.com/NationalSecurityAgency/SIMP), a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by default and must be explicitly opted into by administrators.  Please review the `$client_nets`, `$enable_*` and `$use_*` parameters in `manifests/init.pp` for details.


## Setup


### What ima affects

--------------------------------------------------------------------------------
> **WARNING**
>
> Inserting poorly-formed or incorrect policy into the IMA policy file could
> cause your system to become read-only. This can be temporarily remedied by a
> reboot. This is the current case with the way the module manages the policy
> and it is not recommended to use this section of the module at this time.

--------------------------------------------------------------------------------

This module will:
*  Enable IMA on the host
  * (*OPTIONAL*) Manage the IMA policy (BROKEN - See Limitations)


### Setup Requirements

In order to use this module or a TPM in general, you must do the following:

1. Enable the TPM in BIOS
2. Set a user/admin BIOS password
3. Be able to type in the user/admin password at boot time, every boot


### Beginning with the IMA module

```yaml
classes:
  - ima
```

To enable IMA, add this to hiera:

```yaml
ima::use_ima: true
```

## Usage

### IMA

The current RedHat implementation of IMA does not seem to work after inserting
our default policy (generated example in `spec/files/default_ima_policy.conf`).
It causes the system to become read-only, even though it is only using supported
configuration elements. The module will be updated soon with more sane defaults
to allow for at least the minimal amount of a system to be measured.

To get started, include the `ima::policy` class and set these parameters.
From there, they can be changed to `true` on one by one:

```yaml
ima::policy::measure_root_read_files: false
ima::policy::measure_file_mmap: false
ima::policy::measure_bprm_check: false
ima::policy::measure_module_check: false
ima::policy::appraise_fowner: false
```

## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/master/contributors_guide/Contribution_Procedure.html)


### Acceptance tests

**TODO:** There are currently no acceptance tests. We would need to use a
[virtual TPM](https://github.com/stefanberger/swtpm/) to ensure test system
stability, and it requires quite a few patches to libvirt, associated
emulation software, Beaker, and Vagrant before acceptance tests for this module become feasible. Read
our [progress so far on the issue](https://simp-project.atlassian.net/wiki/x/CgAVAg).
