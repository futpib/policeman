

source_root="src"
build_root="build"


all () {
  clean && gen && echo "Done all" || exit 1
}

gen () {
  copy && \
  make_coffee && \
  make_jison && \
  manifest_locales && \
  properties && \
  svg || \
  exit 1
}

copy () {
  rsync -qav --exclude=".*" $source_root/* $build_root
}

make_coffee () {
  echo "Compiling coffee to js..."
  coffee_files="$(find $build_root -type f -name '*.coffee')"
  for f in $coffee_files
  do
    coffee -cbp $f | tee ${f/%.coffee/.js} >/dev/null
    coffee_status=${PIPESTATUS[0]}
    [ 0 -ne $coffee_status ] && exit $coffee_status
    rm $f
  done
}

make_jison () {
  echo "Compiling jison to js..."
  jison_files="$(find $build_root -type f -name '*.jison')"
  for f in $jison_files
  do
    jison -o ${f/%.jison/.js} ${f} || exit 1
    rm $f
  done
}

svg () {
  echo "Rasterizing svg icons..."
  icons="$(find $build_root/chrome/skin -type f -name '*-icon.svg')"
  for f in $icons
  do
    inkscape -z -e ${f/%.svg/-16.png} -w 16 -h 16 ${f} >/dev/null
    inkscape -z -e ${f/%.svg/-32.png} -w 32 -h 32 ${f} >/dev/null
    inkscape -z -e ${f/%.svg/-64.png} -w 64 -h 64 ${f} >/dev/null
  done
  for f in "$build_root/icon.svg"
  do
    inkscape -z -e ${f/%.svg/.png} -w 64 -h 64 ${f} >/dev/null
  done
}

manifest_locales () {
  echo "Listing locales in chrome.manifest..."
  format="$(grep '^locale\s' "$build_root/chrome.manifest")"
  sed -ni '/^locale\s/!p' $build_root/chrome.manifest
  locales="$(find $build_root/chrome/locale/ \
                  -mindepth 1 -maxdepth 1 -type d -printf "%f\n")"
  for l in $locales
  do
    echo ${format//\$\{locale\}/$l} >> "$build_root/chrome.manifest"
  done
}

properties () {
  echo "Cloning properties to dtd..."
  props="$(find $build_root/chrome/locale -type f -name '*.properties')"
  for f in $props
  do
    cat $f | grep -vE '(^#|^$)' \
      | grep -vE '(^|[^\%])(%%)*(%[0-9]+)' \
      | perl -pe 's/^"?(.+)"?\s*=\s*"?(.*)"?\n$/<!ENTITY \1 "\2">\n/' \
      | tee ${f/%.properties/.dtd} >/dev/null
  done
}

pack () {
  all
  echo "Packaging..."
  pushd $build_root >/dev/null
  zip -qr Policeman.xpi * || exit 1
  popd >/dev/null
}

clean () {
  echo "Performing clean..."
  rm -rf $build_root
}

case "$1" in
"clean")
    clean || exit 1
    ;;
"pack")
    pack || exit 1
    ;;
*)
    all || exit 1
    ;;
esac
