#lang racket

;; Copyright 2016 FoAM vzw
;;
;; Author: nik gaffney <nik@fo.am>
;; Created: 2016-05-05
;; Version: 0.1
;; Keywords: tumblr, import, frog, blog, staticgen, archive
;; X-URL: https://github.com/zzkt/tumblr2frog

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; converts tumblr posts to a format compatible with frog
;;  (assumming both tumblr-utils and frog are installed)
;;  - https://github.com/greghendershott/frog
;;  - https://github.com/bbolli/tumblr-utils
;;
;; initial import
;;  - python tumblr_backup.py -j example.com 
;;  - import a folder recursively (import-folder json-folder) 
;;  - import a sigle file (import-post json-file)
;;  - raco frog -b
;;  
;; incremental import
;;  - python tumblr_backup.py -ji example.com 
;;  - rebuild or run frog with -ws flag
;;
;; post handing
;;  - types: text, quote, link, photo, video
;;  - not yet: audio, chat
;;
;; known problems
;;  - posts from the same day, with the same title will be exported to .md with unique files
;;    while frog assumes unique titles on a given day
;;  - quite slow
;; 
;; TODO
;;  - progress -> log file
;;  - error handling
;;  - save file dialog [replace, rename, skip] to avoid overwritings 
;;  - parameterize
;;  - commandline via raco c.f. https://docs.racket-lang.org/raco/command.html?q=command%20line
;;  - progress estimates
;;  - convert to parser combinator w. parsack

(require json net/url racket/date)

;; folder & import settings

;; folder containing tumblr posts in json format (via python tumblr_backup.py -j agalmic.org)
(define json-folder "/path/to/blog/json/import/")

;; output folders for frog posts and any external media
(define media-folder "//path/to/blog/media/") ;; to store any downloaded data
(define media-prefix "/media/") ;; prefix for rendered media links
(define frog-folder "/path/to/blog/") ;; toplevel of the frog --init folder

;; logging
(define log-file "/path/to/import.log") 

(define save? (make-parameter #t)) ;; save files to <forg-folder>/_src/posts/ when #t otherwise print to stdout (what about 'mirror?)


;; import json format tumblr posts from folder (and subfolders)

(define (import-json-folder)
  (printf "\n[~a] beginning import" (timestamp))
  (parameterize ([current-directory json-folder])
    (for ([p (in-directory)])
      (when (equal? (filename-extension p) #"json")
        (begin (printf "\nimporting: ~a" p)
               ;(printf ".")
               ;(sleep 0.5) ;; pseudo rate limiting
               (extract-post p)))))
  (printf "\n[~a] finished import\n" (timestamp)))

;(import-json-folder) 


;; read json formatted tumblr post from file
(define (import-post file-path)
  (let ([file file-path])
    ;(with-handlers ([exn:fail? (λ (e) (string-append "can't load json file: " file-path))])
    (string->jsexpr (file->string file))))

;(import-post json-file)

;; reformatting tumblr -> frog

(define (format-text text)
  (string-replace text "~" "~~")) ;; since fprintf interprets "~" as escape char 

(define (format-tags list)
  (string-join list ", "))

;; convert from something like "2013-10-07 13:47:29 GMT" to 8601
(define (format-date string)
  (string-replace (substring string 0 19) " " "T"))

;; remove linebreaks and subheadings from titles
(define (format-title s)
  (let* ([s1 (string-replace s "\n" " ")]
         [s2 (if (string-contains? s1 "\r")
                 (car (string-split s1 "\r")) s1)])
    (format-text s2)))

;; photo posts are represented as hashes of one or more images
(define (format-photos photos caption [mirror #f])
  (let ([img-acc
         (map (lambda (i)
                (let* ([photo      (hash-ref i 'original_size "")]
                       [photo-url  (hash-ref photo 'url "")])
                  (if mirror
                      (begin (save-image photo-url)
                             (string-append "\n![](" media-prefix 
                                            (car (regexp-match #px"\\w+\\.(jpe?g|png|gif)" photo-url))  ")\n"))
                      (format "\n![image](" photo-url  ")\n"))))
              photos)])
    (format "~a\n~a\n"
            (string-join
             (if (< 1 (length img-acc))
                 (flatten (list (car img-acc) "\n<!--more-->\n" (cdr img-acc)))
                 img-acc))
            caption)))


;; video with iframe player 500px wide
(define (format-video player permalink caption)
  (string-append 
         (hash-ref (car (filter (lambda (x) (= 500 (hash-ref x 'width))) player)) 'embed_code)
         "\n[video link](" permalink ")\n\n"
         caption
    ))

;; downlod images to media-folder

(define (save-image url)
  (let* ([name (car (regexp-match #px"\\w+\\.(jpe?g|png|gif)" url))]
         [i (get-pure-port (string->url url))]
         [o (open-output-file (string-append media-folder "/" name) #:exists 'replace)]) ;; todo: name and format check	 
    (copy-port i o)))

(define (0L n)
  (~a n #:width 2 #:align 'right #:left-pad-string "0"))

(define (timestamp)
  (date-display-format 'iso-8601)
  (let ([now (seconds->date (current-seconds))])
    (format "~a ~a:~a:~a ~a"
            (date->string now)
            (0L (date-hour now))
            (0L (date-minute now))
            (0L (date-second now))
            (date*-time-zone-name now))))


;; post types
;;  - text, quote, link, photo, video
;; 
;; format/data notes
;; - photos don't usually have a 'title, but mostly 'caption and 'summary
;; - text post often have a 'title
;; - any string fields could contain html, frog/markdown appears ok with this
;; - Q: are there non-quote posts that contain 'text?
;; - photosets have a layout value, which isn't currently used (i.e all posts are 111...)


;; - should probably have reasonable failure-result handlers for missing values

(define (extract-post json)
  (let* ([jpost (import-post json)]
         [post-date  (hash-ref jpost 'date)]
         [post-type  (hash-ref jpost 'type)]
         [post-id    (hash-ref jpost 'id)]
         [post-title (hash-ref jpost 'title "")]
         [post-tags  (hash-ref jpost 'tags "")]
         
         ;; text post
         [post-body  (hash-ref jpost 'body "")]
         
         ;; photo post
         [post-photos  (hash-ref jpost 'photos "")]
         
         ;; quote post
         [post-text   (hash-ref jpost 'text "")]
         [post-source (hash-ref jpost 'source "")]
         
         ;; link post
         [post-description (hash-ref jpost 'description "")]         
         [post-link (hash-ref jpost 'url "")]
         
         ;; video post
         [post-video-type (hash-ref jpost 'video_type "")]
         [post-permalink (hash-ref jpost 'permalink_url "")] 
         [post-video (hash-ref jpost 'video "")]
         [post-player (hash-ref jpost 'player "")]
         
         ;; some or most
         [post-summary (hash-ref jpost 'summary "")] ;; photo, link, video
         [post-caption (hash-ref jpost 'caption "")] ;; photo, video
         
         
         [post-slug (hash-ref jpost 'slug "")]
         [post-url (hash-ref jpost 'post_url "")]
         
         ;; frog 
         [frog-date  (format-date post-date)]
         [frog-tags  (format-tags post-tags)]
         [frog-title (format-title
                      (cond
                        [(non-empty-string? post-title) post-title]
                        [(non-empty-string? post-summary)  post-summary]
                        [(non-empty-string? post-description) post-description]
                        [(format "untitled ~a" post-id)]))]
         [frog-body  (format-text
                      (cond
                        [(string=? post-type "text")  post-body]
                        [(string=? post-type "quote")
                         (format "\n<span class='quote'>“~a”</span>\n\n–<span class='quote-source'>~a</span>"
                                 post-text post-source)]
                        [(string=? post-type "link")
                         (format "~a\n\n[~a](~a)" post-description post-summary post-link)]
                        [(string=? post-type "photo")
                         (format-photos post-photos post-caption #t)]
                        [(string=? post-type "video")
                         (format-video post-player post-permalink post-caption)]
                        ["<!--empty body-->"]))]        
         [frog-file-path  (format "~a/_src/posts/~a-~a-~a.md"
                                  frog-folder 
                                  (substring post-date 0 10)
                                  post-slug post-id )]
         
         ;; formatting as frog source post. metadata followed by markdown/html body
         [frog-post (string-append
                     "    Title: "   frog-title
                     "\n    Date: "  frog-date  
                     "\n    Tags: "  frog-tags 
                     "\n\n"          frog-body 
                     "\n\n<!-- tumblr url: [" post-url "](" post-url ") -->\n" )])
    
    (if save?
        (let ([o (open-output-file frog-file-path #:exists 'replace)])
          ;(printf "\nwriting: ~a" frog-file-path)
          (fprintf o frog-post)
          (close-output-port o))
        (printf frog-post))
    ))


