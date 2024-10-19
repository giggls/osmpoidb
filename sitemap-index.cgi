#!/usr/bin/python
# -*- coding: UTF-8 -*-
#
# Generate multilingual xml sitemaps for OpenCampingMap
#
#
import psycopg2
import re
import os

dbconnstr="dbname=poi"
index_query = "SELECT distinct tags ->> 'addr:country' AS country,max(timestamp) as timestamp FROM osm_poi_campsites WHERE tags ? 'addr:country' AND visible = TRUE GROUP BY country;"

sitemap_path = b"/sitemaps"

# If another language is added to OpenCampingMap this template needs to be modified
# as wenn as the code where it gets filled
url_template = '''\t<url>
\t\t<loc>%s/en/%s/%d</loc>
\t\t<xhtml:link rel="alternate" hreflang="en" href="%s/en/%s/%d"/>
\t\t<xhtml:link rel="alternate" hreflang="de" href="%s/de/%s/%d"/>
\t\t<xhtml:link rel="alternate" hreflang="fr" href="%s/fr/%s/%d"/>
\t\t<xhtml:link rel="alternate" hreflang="es" href="%s/es/%s/%d"/>
\t\t<xhtml:link rel="alternate" hreflang="ru" href="%s/ru/%s/%d"/>
\t\t<lastmod>%s+00:00</lastmod>
\t</url>
'''.encode()

def gen404(path):
    status = '404 Not Found'
    headers = [('Content-type', 'text/html; charset=utf-8')]
    body=b'<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<title>Error</title>\n</head>\n<body>\n<pre>Cannot GET %s</pre>\n</body>\n</html>\n' % path
    return status,headers,body

def dbError():
    status = '404 Not Found'
    headers = [('Content-type', 'text/html; charset=utf-8')]
    body=b'<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<title>Error</title>\n</head>\n<body>\n<pre>Unable to connect to database!</pre>\n</body>\n</html>\n'
    return status,headers,body

def genSiteMapIndex(conn,baseurl):
    status = '200 OK'
    headers = [('Content-type', 'text/xml')]
    body=b'<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    cur = conn.cursor()
    cur.execute(index_query)
    res = cur.fetchall()
    cur.close()
    for r in res:
      body=body+b'\t<sitemap>\n'
      body=body+b'\t\t<loc>%s/%s.xml</loc>\n' % (os.path.dirname(baseurl)+sitemap_path,r[0].encode())
      body=body+b'\t\t<lastmod>%s+00:00</lastmod>\n' % r[1].isoformat().encode()
      body=body+b'\t</sitemap>\n'
    body=body+b'</sitemapindex>\n'
    conn.close()
    return status,headers,body
    
def application(environ, start_response):
    dberror = False
    try:
      dbcon = psycopg2.connect(dbconnstr)
    except:
      dberror = True
      
    if dberror:
      status,headers,body = dbError()
    else:
      if environ['PATH_INFO'] == '':
        status,headers,body = genSiteMapIndex(dbcon,environ['SCRIPT_URI'].encode())
      else:
        status,headers,body = gen404(bytes(environ['REQUEST_URI'],"utf-8"))
    start_response(status, headers)
    return [body]

