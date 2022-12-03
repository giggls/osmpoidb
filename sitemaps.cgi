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
sitemap_query = "SELECT osm_type,osm_id,timestamp FROM osm_poi_campsites WHERE tags->'addr:country' = '%s' AND tags ? 'name' AND visible = TRUE;"

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

osm_type = {'N':b'node','W':b'way','R':b'relation'}

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

def genSiteMap(conn,baseurl,country):
    status = '200 OK'
    headers = [('Content-type', 'text/xml')]
    body = b'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n'
    body +=  b'\txmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
    cur = conn.cursor('smc')
    cur.execute(sitemap_query % country)
    res = cur.fetchall()
    # this construction seems to be faster than a for loop
    #body += b"".join([b'\t<url>\n\t\t<loc>%s/en/%s/%d</loc>\n\t\t<lastmod>%s+00:00</lastmod>\n\t</url>\n' % (baseurl,osm_type[r[0]],r[1],r[2].isoformat().encode()) for r in res])
    body += b"".join([url_template % (baseurl,osm_type[r[0]],r[1],baseurl,osm_type[r[0]],r[1],baseurl,osm_type[r[0]],r[1],baseurl,osm_type[r[0]],r[1],baseurl,osm_type[r[0]],r[1],baseurl,osm_type[r[0]],r[1],r[2].isoformat().encode()) for r in res])
    body += b'</urlset>\n'
    cur.close()
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
      if re.match("^/[a-z][a-z].xml$",environ['PATH_INFO']):
        status,headers,body = genSiteMap(dbcon,os.path.dirname(os.path.dirname(environ['SCRIPT_URI'])).encode(),environ['PATH_INFO'][1:3])
      else:
        status,headers,body = gen404(bytes(environ['REQUEST_URI'],"utf-8"))
    start_response(status, headers)
    return [body]

