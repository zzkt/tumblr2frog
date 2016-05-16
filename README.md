# tumblr → frog

`tumblr->frog` converts tumblr ("Use it however you like") posts to a format compatible with frog ("Q: 'Frog'?
A: Frozen blog") it depends on both [tumblr-utils](https://github.com/bbolli/tumblr-utils) and [frog](https://github.com/greghendershott/frog) being installed. 

# import

- create a backup of your tumblr site in json format. `python tumblr_backup.py -j example.com`
- sort out the various paths and folder names and set the relevant values/args
  - folder to import **from** (the `json-folder`) containing the tumlbr posts in json format
  - blog to import **to** (the `frog-folder`) which is a top level frog folder (i.e. `frog --init`)
  - if you are importing any external media from tumlbr (images, video, etc)
    - the folder to download external media into (the `media-folder`)
	- the base-url for generated links (the `media-prefix`) 
- start the import by calling `(import-json-folder)` which will recursively import any json files in the `json-folder` 
- it's also possible to import a single file using `(import-post "/path/to/file.json")` 
- the imported posts should now be in `_src/posts/` in a format suitable for `frog`
- build and preview the html files with `raco frog -bp`

# incremental import

- `python tumblr_backup.py -ji example.com` 
-  `(import-json-folder)` with new files
- rebuild or run `frog` with `-ws` flag 

# known bugs

 - no unit tests
 - currently imports text, quote, link, photo and video posts (no 'audio' or 'chat' yet)
 - tumblr posts from the same day, with the same title will be exported to markdown files with unique filenames however frog assumes unique titles on a given date, so will only generate a single html file (this can be fixed by changing titles)
 - quite slow
 
