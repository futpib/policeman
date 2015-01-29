#!/bin/bash

root="."
build_root="$root/build"
source_root="$root/src"
tests_source_root="$root/test"

tester_args=""

do_build=true
do_pack=false
do_svg=true
do_test=false

hr () {
  if [ -z "$1" ]; then
    printf '%80s\n' | tr ' ' =
  else
    printf '%80s' | tr ' ' =
    printf '%80s' | tr ' ' $'\b'
    echo "$1"
  fi
}

build () {
  clean || return 1

  if [ "$do_build" = true ]; then
    generate || return 1
  fi

  if [ "$do_test" = true ]; then
    test_ || echo "Testing failed."
  fi

  if [ "$do_pack" = true ]; then
    pack || return 1
  fi

  echo "Done all"
}

generate () {
  copy && \
  make_coffee && \
  make_jison && \
  manifest_locales && \
  properties || return 1

  if [ "$do_svg" = true ]; then
    svg || return 1
  fi
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
    [ 0 -ne $coffee_status ] && return $coffee_status
    rm $f
  done
}

make_jison () {
  echo "Compiling jison to js..."
  jison_files="$(find $build_root -type f -name '*.jison')"
  for f in $jison_files
  do
    jison -o ${f/%.jison/.js} ${f} || return 1
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

properties_extract_keys () {
  grep -v "^#"  "$1" | sed 's/\s*=.*$//g'
}
properties_line_by_key () {
  grep "^$1\s*=" "$2"
}
properties () {
  echo "Cloning properties to dtd..."

  model_locale="$build_root/chrome/locale/en-US/policeman.properties"
  declare -A model_keys
  for key in $(properties_extract_keys $model_locale)
  do
    model_keys["$key"]=1
  done

  props="$(find $build_root/chrome/locale -type f -name '*.properties')"
  for f in $props
  do
    # take missing keys from model_locale
    for key in "${!model_keys[@]}"
    do
      # FIXME fails for multiline values
      if [ -z "$(properties_line_by_key $key $f)" ]
      then
        properties_line_by_key "$key" "$model_locale" >> $f
      fi
    done

    cat $f | grep -vE '(^#|^$)' \
      | grep -vE '(^|[^\%])(%%)*(%[0-9]+)' \
      | perl -pe 's/^"?(.+)"?\s*=\s*"?(.*)"?\n$/<!ENTITY \1 "\2">\n/' \
      | tee ${f/%.properties/.dtd} >/dev/null
  done
}

pack () {
  echo "Packaging..."
  pushd $build_root >/dev/null
  zip -qr Policeman.xpi * || return 1
  popd >/dev/null
}

test_ () {
  tmp="$(mktemp -d --suffix=.policeman.tests)"
  rsync -qav --exclude=".*" "$tests_source_root"/* "$tmp" | return 1

  echo "Compiling coffee tests to js..."
  coffee_files="$(find $tmp/cases -mindepth 2 -type f -name '*.coffee')"
  for f in $coffee_files
  do
    cat "$tmp/cases/test-header.coffee" "$f" \
            | coffee -cbps \
            | tee "${f/%.coffee/.js}" >/dev/null
    coffee_status=${PIPESTATUS[0]}
    [ 0 -ne $coffee_status ] && return $coffee_status
    rm "$f"
  done

  hr "=== Started tester "
  eval python2 "$root/test/tester/main.py" "$tester_args" "$tmp" "$build_root" \
          || return 1
  hr "=== Tester exited "

  rm -r "$tmp"
}

clean () {
  echo "Performing clean..."
  if [ "$do_svg" = false ]; then # keep icons
    find "$build_root" -type f -not -name '*.png' -print0 | xargs -0 rm
  else
    rm -rf $build_root
  fi
}

print_help () {
cat << _EOF_
Build script for Policeman Firefox add-on
Usage: $0 [OPTION]...
  -c, --clean-only      Clean build directory and exit
  -i, --keep-icons      Do not delete and do not rasterize svg icons (faster)
  -p, --pack            Pack add-on into an xpi file in the build directory
  -t, --test            Run tests after build
      --tester-args=STR Arguments passed to the tester script
  -r, --root=DIR        Repository root directory (default: current directory)
  -h, --help            display this help and exit

This script depends at least on the following tools:
  coffee                CoffeeScript compiler
  jison                 Jison compiler
  mozmill               Mozmill Gecko testing framework
  inkscape              Vector graphics editor (for svg icons rasterization)
  zip                   Zip compression utility (for packaging on xpi file)
_EOF_
}

main () {
  args=$(getopt -o hcitpr: \
                -l help,clean-only,keep-icons,test,pack,root: \
                -- "$@")
  eval set -- "$args"

  while [ ! -z "$1" ]
  do
    case "$1" in
      -c|--clean-only)
        do_build=false
        shift
      ;;
      -i|--keep-icons)
        do_svg=false
        shift
      ;;
      -p|--pack)
        do_pack=true
        shift
      ;;
      -t|--test)
        do_test=true
        shift
      ;;
      --tester-args)
        tester_args="$2"
        shift 2
      ;;
      -r|--root)
        root="$2"
        shift 2
      ;;
      -h|--help)
        print_help
        shift
        return 0
      ;;
      --)
        shift
        break
      ;;
      *)
        echo "Something wrong with arguments"
        print_help
        return 1
      ;;
    esac
  done

  build || return 1
}

main "$@"
exit "$?"
