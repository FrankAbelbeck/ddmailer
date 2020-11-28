# Dead Drop Mailer

Copyright (C) 2020 Frank Abelbeck <frank.abelbeck@googlemail.com>

License: GLP 3

## Overview

The Dead Drop Mailer (DDMailer) is a mail transfer agent (MTA) dealing with
system-local e-mails. But instead of sending them (e.g. via SMTP) it writes them
to existing system-local mailbox structures or remote IMAP accounts.

Hence the name: It drops e-mails in existing mailboxes/accounts without causing
e-mail traffic. [Cf. Bruce Schneier](https://www.schneier.com/tag/dead-drops/)

The reason for this is not operational security but being able to send message
from my home server to me when being outside my home network. Today's spam
guards make setting up an own e-mail server or just a simple MTA like nullmailer
a PITA. So I wrote a MTA daemon on my own in order to route server messages to
a freemail account. By appending e-mails to an existing TLS-IMAP account,
I could avoiding e-mail traffic pitfalls and ensure basic information security.

As development tradition mandates, a little feature creep occured: I enabled my
daemon to deliver the e-mails to multiple accounts, added support for local
mailbox structures (Maildir, MH) and created a simple regex/substitute filter
system (in case some system service mangled "From", "To" or "Subject" fields.

## Architecture

DDMailer is divided in a server process called DDMailer Daemon (Disk And
Execution MONitor), short *ddmailerd*, and a *sendmail* program. Both are
written in Python so you can easily look what they are doing.

 * **ddmailerd** is listening on a localhost UDP port for messages. If it
   receives a datagram "PID", ddmailerd answers with its process ID as an 8
   bytes big-endian integer. Otherwise it parses the datagram as RFC compliant
   e-mail, filters and delivers it to the defined accounts.

 * **sendmail** reads stdin until either EOF or a line with a single dot is
   reached. Then it creates an RFC-compliant e-mail and addresses it to the
   recipients given as positional arguments. Or in other words: it mimics the
   original sendmail's behaviour except for any commandline options (ignored).
   The created e-mail is sent to the UDP port of ddmailerd. To avoid size error
   exceptions the e-mail is clipped at 65507 bytes (maximum datagram size
   2**16-1 minus 8 bytes UDP header minus 20 bytes IPv4 header). 

## Daemon Commands

ddmailerd accepts the following commands as single positional argument:

 * **start:** Start the program; reads the configuration files and listens on
   the defined UDP port at localhost; if it receives a datagram with the bytes
   "PID", then the program answers with its own PID, encoded as 8 bytes
   big-endian integer. Has to be run as user root.

 * **stop:** Stop the program; sends PID to the defined UDP port at localhost,
   decodes the returned 8 bytes bid-endian integer and issues SIGTERM to that
   PID. This in turn breaks the processing loop of the running program, so that
   it gracefully terminates. Has to be run as user root.
   
 * **status:** Checks if someone is listening at the defined port by sending a
   PID datagram. The program exits with the following codes (cf. [LSB 5.0](https://refspecs.linuxbase.org/LSB_5.0.0/LSB-Core-generic/LSB-Core-generic/iniscrptact.html)):
   
   * **0**   daemon is running or service is OK
   * **1**   daemon is dead and UDP socket is bound
   * **3**   daemon is not running
   * **4**   daemon status is unknown

 * **info:** Print some information on ddmailerd.
 * **cfgMain:** Print contents of a basic main configuration file to stdout.
 * **cfgAccount:** Print contents of a basic account configuration file to stdout.

ddmailerd does not manage a PID file. It uses the pre-defined UDP port as means
of daemon control.

## Pathes

The sendmail program should be placed in /usr/sbin because some system tools
have hard-coded pathes to the sendmail program.

The ddmailerd program can be placed in either /usr/bin or /usr/sbin. According
to the [FSH](https://refspecs.linuxbase.org/FHS_3.0/fhs/index.html), /usr/sbin
is appropriate since normally root would start ddmailerd (which in turn drops
privileges to the user ddmailer).

The main configuration file "ddmailerd.ini" and the account configuration file
"ddmailerd.account.ini" are expected to reside in /etc.

## Configuration

There are two different configuration files. Self-explaining examples can be
obtained by calling `ddmailerd cfgMain` and `ddmailerd cfgAccount`.

 * **ddmailerd.ini** at least defines port and the socket timeout value. This
   file is essential for both programs. In addition, daemon behaviour can be
   tweaked and filters can be defined. In order to allow normal users to call
   sendmail, file permissions should be less restrictive (0666).
   
 * **ddmailerd.account.ini** defines IMAP accounts and system-local mailboxes.
   It is split from the main configuration file in order to store sensitive
   information like username/password safely. File permissions should be
   restrictive (0600), as this file is only read by user root during start-up,
   before dropping privileges.

If you intend to use a system-local mailbox, make sure that ddmailer as well as
your users can access that mailbox. On my notebook I run the following setup for
a local system mailbox:

1. Directory /var/mail with owner and group ddmailer and permissions 770
2. Regular user added to group ddmailer
3. Inside /var/mail: MH mailbox, desktop access via Claws Mail

## Installation: From Source

The following steps assume being run on a standard Linux system with OpenRC as user root.
Further it is assumed that $GITDIR equals your local ddmailer repo path.

NOTE: If you've already installed another MTA it might be that
/usr/sbin/sendmail exists. In that case it's up to you to resolve the conflict.

1. Place `$GITDIR/sbin/ddmailerd` and `$GITDIR/sbin/sendmail` in `/usr/sbin`
2. Place `$GITDIR/openrc/ddmailerd` in `/etc/init.d`
3. Set permissions with `chmod 755 /etc/init.d/ddmailerd /usr/sbin/ddmailerd /usr/sbin/sendmail`
4. Create basic main configuration file with `/usr/sbin/ddmailerd cfgMain > /etc/ddmailerd.ini`
5. Create basic account configuration file with `/usr/sbin/ddmailerd cfgAccount > /etc/ddmailerd.account.ini`
6. Set permission on main configuration file with `chmod 666 /etc/ddmailerd.ini`
7. Set permission on account configuration file with `chmod 600 /etc/ddmailerd.account.ini`
8. Edit these configuration files
9. Add ddmailerd to the default runlevel with `rc-update add ddmailerd default`
10. Create user ddmailer with `useradd --system ddmailer`
10. Start ddmailerd with `/etc/init.d/ddmailerd start`
11. Test it with `echo -e "Subject: Test\r\nThis is a test" | sendmail info`

## Installation: Gentoo

I created four ebuilds which can be found in the `portage` subdirectory:

1. acct-group/ddmailer/ddmailer-0.ebuild
2. acct-user/ddmailer/ddmailer-0.ebuild
3. mail-mta/ddmailer/ddmailer-9999.ebuild
4. virtual/mta/mta-0.ebuild

Copy these contents of `portage` into your local portage repository. You can
find instruction for creating your own local portage repo in the [Gentoo Handbook](
https://wiki.gentoo.org/wiki/Handbook:AMD64/Portage/CustomTree#Defining_a_custom_ebuild_repository).

Run `repoman manifest` in every ebuild directory (builds the Manifest file).

Mask the virtual/mta package of the official gentoo repository by issuing

```bash
echo "virtual/mta::gentoo" >> /etc/portage/package.mask/virtual
```

Now everytime a package requests an MTA, ddmailer will get automagically chosen.
To install ddmailer, just run

```bash
emerge -1va virtual/mta
```

## Changelog

 * **2020-11-23** Initial commit; bugfixes (first time I wrote a complex ebuild)

 * **2020-11-27** Introduced message limit in sendmail to avoid errno 90 exceptions
