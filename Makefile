default: minipost.link.secret.key minipost.link.csr sin.minipost.link nyc.minipost.link

clean:
	rm sin.minipost.link.crt sin.minipost.link.secret.key
	rm nyc.minipost.link.secret.key nyc.minipost.link.crt


# Make secret key and certificate for nyc.minipost.link
nyc.minipost.link: nyc.minipost.link.secret.key nyc.minipost.link.crt

nyc.minipost.link.secret.key:
	fly certify:nyc

nyc.minipost.link.crt: nyc.minipost.link.secret.key
	fly certify:nyc


# Make secret key for minipost.link
minipost.link.secret.key:
	openssl genrsa -out minipost.link.secret.key 2048

# Make certificate signing request for minipost.link
minipost.link.csr: minipost.link.secret.key
	openssl req -new -key minipost.link.secret.key -out minipost.link.csr -subj "/CN=minipost.link"
	openssl req -noout -text -in minipost.link.csr


# Make secret key and certificate for sin.minipost.link
sin.minipost.link: sin.minipost.link.secret.key sin.minipost.link.crt

# The secret key is a copy of the minipost.link secret.
sin.minipost.link.secret.key: minipost.link.secret.key
	cp minipost.link.secret.key sin.minipost.link.secret.key

# PEM encoded file that includes the minipost.link certificate and the intermediate certificate.
sin.minipost.link.crt: minipost.link.crt GandiStandardSSLCA.pem
	rm -f sin.minipost.link.crt
	touch sin.minipost.link.crt
	cat minipost.link.crt >> sin.minipost.link.crt
	cat GandiStandardSSLCA.pem >> sin.minipost.link.crt


# Download intermediate certificate from Gandi.
GandiStandardSSLCA.pem:
	curl -O https://www.gandi.net/static/CAs/GandiStandardSSLCA.pem \
		> GandiStandardSSLCA.pem
