;;; guix.scm -- Guix package definition

;;; XyGrib - Weather Forecast Visualization
;;; Copyright © 2018. 2019 Efraim Flashner <efraim@flashner.co.il>
;;;
;;; guix.scm: This file is part of XyGrib.
;;;
;;; XyGrib is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; XyGrib is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with XyGrib.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; GNU Guix development package.  To build and install, run:
;;
;;   guix package -f guix.scm
;;
;; To build it, but not install it, run:
;;
;;   guix build -f guix.scm
;;
;; To use as the basis for a development environment, run:
;;
;;   guix environment -l guix.scm
;;
;;; Code:

(use-modules (srfi srfi-1)
             (srfi srfi-26)
             (ice-9 match)
             (ice-9 popen)
             (ice-9 rdelim)
             (gnu packages)
             (gnu packages autotools)
             (gnu packages compression)
             (gnu packages fonts)
             (gnu packages geo)
             (gnu packages image)
             (gnu packages qt)
             ((guix build utils) #:select (with-directory-excursion))
             (guix build-system cmake)
             (guix build-system gnu)
             (guix gexp)
             (guix git-download)
             (guix utils)
             ((guix licenses) #:prefix license:)
             (guix packages))

(define %source-dir (dirname (current-filename)))

(define git-file?
  (let* ((pipe (with-directory-excursion %source-dir
                 (open-pipe* OPEN_READ "git" "ls-files")))
         (files (let loop ((lines '()))
                  (match (read-line pipe)
                    ((? eof-object?)
                     (reverse lines))
                    (line
                     (loop (cons line lines))))))
         (status (close-pipe pipe)))
    (lambda (file stat)
      (match (stat:type stat)
        ('directory #t)
        ((or 'regular 'symlink)
         (any (cut string-suffix? <> file) files))
        (_ #f)))))

(define libnova
  (package
    (name "libnova")
    (version "0.16")
    (source
      (origin
        (method git-fetch)
        (uri (git-reference
               (url "https://git.code.sf.net/p/libnova/libnova.git")
               (commit (string-append "v" version))))
        (file-name (git-file-name name version))
        (sha256
         (base32
          "0icwylwkixihzni0kgl0j8dx3qhqvym6zv2hkw2dy6v9zvysrb1b"))))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-git-version
           (lambda _
             (substitute* "./git-version-gen"
               (("/bin/sh") (which "sh")))
             #t)))))
    (native-inputs
     `(("autoconf" ,autoconf)
       ("automake" ,automake)
       ("libtool" ,libtool)))
    (synopsis "celestial mechanics, astrometry and astrodynamics library")
    (description "Libnova is a general purpose, double precision, Celestial
Mechanics, Astrometry and Astrodynamics library.")
    (home-page "http://libnova.sourceforge.net/")
    (license (list license:lgpl2.0
                   license:gpl2)))) ; examples/transforms.c & lntest/*.c

(define-public xygrib
  (package
    (name "xygrib")
    (version "1.2.6")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                     (url "https://github.com/opengribs/XyGrib.git")
                     (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0qzaaavil2c7mkkai5mg54cv8r452i7psy7cg75qjja96d2d7rbd"))
              (modules '((guix build utils)))
              (snippet
               '(begin (delete-file-recursively "data/fonts") #t))))
    (build-system cmake-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-directories
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((jpeg (assoc-ref inputs "openjpeg"))
                   (font (assoc-ref inputs "font-liberation")))
               (substitute* "CMakeLists.txt"
                 ;; Find libjpeg.
                 (("/usr") jpeg)
                 ;; Fix install locations.
                 (("set\\(PREFIX_BIN.*") "set(PREFIX_BIN \"bin\")\n")
                 (("set\\(PREFIX_PKGDATA.*") "set(PREFIX_PKGDATA \"share/${PROJECT_NAME}\")\n")
                 ;; Skip looking for the static library.
                 (("\"libnova.a\"") ""))
               ;; Don't use the bundled font-liberation.
               (substitute* "src/util/Font.cpp"
                 (("Util::pathFonts\\(\\)\\+\"liberation-fonts/\"")
                  (string-append "\"" font "/share/fonts/truetype/\"")))
               (substitute* "src/util/Util.h"
                 (("pathData\\(\\)\\+\"data/fonts/\"")
                  (string-append "\"" font "/share/fonts/\""))))
             #t)))
       #:tests? #f))
    (native-inputs
     `(("qttools" ,qttools)))
    (inputs
     `(("bzip2" ,bzip2)
       ("font-liberation" ,font-liberation)
       ("libnova" ,libnova)
       ("libpng" ,libpng)
       ("openjpeg" ,openjpeg)
       ("proj.4" ,proj.4)
       ("qtbase" ,qtbase)
       ("zlib" ,zlib)))
    (synopsis "Weather Forecast Visualization")
    (description
     "XyGrib is a Grib file reader and visualizes meteorological data providing
an off-line capability to analyse weather forecasts or hindcasts.  It is
intended to be used as a capable weather work station for anyone with a serious
interest in examining weather. This would include members of the sailing
community, private and sport aviators, farmers, weather buffs and many more.
XyGrib is the continuation of the zyGrib software package with a new team of
volunteers.")
    (home-page "https://opengribs.org")
    (license license:gpl3+)))

(define-public xygrib.git
 (let ((revision "0")
       (commit (read-string (open-pipe "git show HEAD | head -1 | cut -d ' ' -f 2" OPEN_READ))))
    (package
      (inherit xygrib)
      (name "xygrib.git")
      (version (string-append (package-version xygrib) "-" revision "." (string-take commit 7)))
      (source
        (local-file %source-dir #:recursive? #t #:select? git-file?)))))

;; Return it here so `guix build/environment/package' can consume it directly.
xygrib
