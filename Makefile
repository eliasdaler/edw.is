.PHONY: serve
serve:
	hugo serve

.PHONY: build
build:
	rm -rf public
	hugo --minify

.PHONY: deploy
deploy: build
	rm -rf public
	hugo --minify
	rsync -av --delete -P --stats --human-readable -e 'ssh -p ${BLOG_SSH_PORT}' public/ debian@${BLOG_IP_ADDRESS}:/var/www/edw.is/html/
