EAPI=7

inherit git-r3

DESCRIPTION="Dead Drop Mailer is a simple SMTP-avoiding mail transfer agent written in Python."
HOMEPAGE="https://github.com/FrankAbelbeck"
LICENSE="GPL-3"
KEYWORDS="amd64"
DEPEND="app-portage/gentoolkit"
RDEPEND="acct-user/ddmailer virtual/logger"
EGIT_REPO_URI="https://github.com/FrankAbelbeck/ddmailer.git"
SLOT="0"

pkg_pretend() {
	# check for existing sendmail program not belonging to ddmailer
	# if found, that collision is not resolvable
	for FILE in /usr/sbin/sendmail /usr/bin/sendmail; do
		if [ -e $FILE ] && [[ "$(equery --quiet belongs --early-out $FILE)" != "mail-mta/ddmailer-9999" ]]; then
			die "Found existing program $FILE not belonging to ddmailer. Sorry, cannot install DDMailer alongside another MTA."
		fi
	done
	einfo "No existing sendmail programs detected."
}

src_install() {
	# install programs and the init script
	dosbin  ${S}/sbin/ddmailerd
	dosbin  ${S}/sbin/sendmail
	
	# necessary since some programs have hard-coded paths to /usr/bin/sendmail
	dosym /usr/sbin/sendmail /usr/bin/sendmail
	
	doinitd ${S}/openrc/ddmailerd
	# extract example configuration files and place them in /etc
	# set permission so that main config is readable by all and account config
	# is solely readable by root
	insinto /etc
	${S}/sbin/ddmailerd cfgMain    | newins - ddmailerd.ini
	${S}/sbin/ddmailerd cfgAccount | newins - ddmailerd.account.ini
	fperms 644 /etc/ddmailerd.ini
	fperms 600 /etc/ddmailerd.account.ini
}

pkg_postinst() {
	elog "Please edit /etc/ddmailerd.ini and /etc/ddmailerd.account.ini."
	elog "At least you should define one IMAPS, Maildir or MH mailbox,"
	elog "otherwise ddmailerd will do nothing."
}
