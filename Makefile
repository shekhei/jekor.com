sites := http://www.vocabulink.com/ http://www.minjs.com/ http://www.domcharts.com/

SHELL := /bin/bash
sasses := $(shell find www -name "text.x-sass")
markdowns := $(shell find www/article -name "text.x-web-markdown")
sync_options := -avz bin etc var www --exclude comment/* --exclude comments/* --exclude var/* --exclude graph/* linode:jekor.com/

all : www/text.html www/articles www/articles/application.json $(sasses:x-sass=css) $(markdowns:x-web-markdown=html) $(markdowns:text.x-web-markdown=application.json) $(markdowns:text.x-web-markdown=comment/POST) $(markdowns:text.x-web-markdown=comments) $(markdowns:text.x-web-markdown=comments/application.json) www/articles/feed/application.rss+xml var/emails

sync :
	rsync $(sync_options)

sync-test :
	rsync --dry-run $(sync_options)

%text.css : %text.x-sass
	sass $< > $@

www/text.html : www/articles/application.json template/front.html template/article-item.html template/site-item.html etc/analytics.js
	cat $< | jw name articles | cat - <(echo $(sites) | tr ' ' "\n" | map "tr -d \"\n\" | jw string | jw name url" | jw array | jw name sites) | jw merge | cat - <(jw string < etc/analytics.js | jw name analytics) | jw merge | jigplate template/front.html template/article-item.html template/site-item.html > $@

www/article/%/application.json : www/article/%/text.x-web-markdown
# TODO: Get rid of name: it's redundant. (To do so requires altering the rule for www/article/%/text.html.)
	head -n 3 $< | cut -d' ' -f2- | cat <(echo -e "name\ntitle\nauthor\ndate") <(echo $$(basename $$(dirname $<))) - | jw ziplines > metadata
	pandoc --smart --section-divs --mathjax -t html5 < $< | jw string | jw name body | cat metadata - | jw merge > $@
	rm metadata

www/article/%/text.html : www/article/%/application.json www/articles/application.json template/article.html template/article-item.html template/nav.html etc/analytics.js
	jw name articles < www/articles/application.json | cat - <(echo $(sites) | tr ' ' "\n" | map "tr -d \"\n\" | jw string | jw name url" | jw array | jw name sites) | jw merge | jigplate template/nav.html template/article-item.html template/site-item.html | jw string | jw name nav | cat - $< | jw merge | cat - <(jw string < etc/analytics.js | jw name analytics) | jw merge | jigplate template/article.html > $@
# jw unarray < www/articles/application.json | grep -v $$(jw lookup name < $<) | head -n 3 | jw array | jw name recent | cat - $< jw merge | jigplate template/article.html template/article-item.html > $@

www/articles :
	mkdir $@

www/articles/application.json : $(markdowns:text.x-web-markdown=application.json)
	cat $^ | paste <(cat $^ | map jw lookup date) - | sort -r | cut -f2 | jw array > $@

www/articles/feed :
	mkdir $@

www/articles/feed/application.rss+xml : www/articles/application.json template/rss-item.xml template/rss.xml www/articles/feed
	cat $< | jw name items | cat - <(date -R | tr -d "\n" | jw string | jw name date) | jw merge | jigplate template/rss-item.xml template/rss.xml > $@

www/article/%/comment :
	mkdir $@ && chmod 777 $@

www/article/%/comment/POST : www/article/%/comment
	ln -sf ../../../../bin/post-comment $@

www/article/%/comments :
	mkdir $@

www/article/%/comments/application.json :
	echo "[]" > $@ && chmod 666 $@

var :
	mkdir $@

var/emails : var
	echo "{}" > $@ && chmod 666 $@
