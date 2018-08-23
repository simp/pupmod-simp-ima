[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/ima.svg)](https://forge.puppetlabs.com/simp/ima)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/ima.svg)](https://forge.puppetlabs.com/simp/ima)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-ima.svg)](https://travis-ci.org/simp/pupmod-simp-ima)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with ima](#setup)
    * [What ima affects](#what-ima-affects)
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
 * If used independently, all SIMP-managed security subsystems are disabled by default and must be explicitly opted into by administrators.  Please review the `$enable_*` and `$manage_*` parameters in `manifests/init.pp` for details.


## Setup


### What ima affects

--------------------------------------------------------------------------------
> **WARNING**
>
> Inserting poorly-formed or incorrect policy into the IMA policy file could
> cause your system to become read-only. This can be temporarily remedied by
> rebooting and temporarily setting ima_appraise to fix in the boot command
> options. This is the current case with the way the module manages the policy
> and it is not recommended to use this section of the module at this time.

--------------------------------------------------------------------------------

This module will:
*  Enable IMA on the host
  * (*OPTIONAL*) Manage the IMA policy (BROKEN - See Limitations)


### Beginning with the IMA module

```yaml
classes:
  - ima
```

To utilize IMA, add this to hiera:

```yaml
ima::manage_policy: true
ima::manage_appraise: true
```

## Usage

## Reference

Please refer to the inline documentation within each source file, or to the
module's generated YARD documentation for reference material.


## Limitations

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS. Please see the
[`metadata.json` file](./metadata.json) for the most up-to-date list of
supported operating systems, Puppet versions, and module dependencies.

The default configuration of this module updates EFI boot parameters if they are 
present. If the system relies upon BIOS for boot, ensure there is not an EFI
grub.cfg or grub2.cfg present or the BIOS grub config file will not be updated.

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

To run the system tests, you need `Vagrant` installed.

You can then run the following to execute the acceptance tests:

```shell
   bundle exec rake beaker:suites
```

Some environment variables may be useful:

```shell
   BEAKER_debug=true
   BEAKER_provision=no
   BEAKER_destroy=no
   BEAKER_use_fixtures_dir_for_modules=yes
```

*  ``BEAKER_debug``: show the commands being run on the STU and their output.
*  ``BEAKER_destroy=no``: prevent the machine destruction after the tests
   finish so you can inspect the state.
*  ``BEAKER_provision=no``: prevent the machine from being recreated.  This can
   save a lot of time while you're writing the tests.
*  ``BEAKER_use_fixtures_dir_for_modules=yes``: cause all module dependencies
   to be loaded from the ``spec/fixtures/modules`` directory, based on the
   contents of ``.fixtures.yml``. The contents of this directory are usually
   populated by ``bundle exec rake spec_prep``. This can be used to run
   acceptance tests to run on isolated networks.
