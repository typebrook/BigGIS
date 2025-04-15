dir=
cat list | \
while read line; do
  if [[ $line =~ '#' ]]; then
    prefix=$(awk '{print $1}' <<<"$line")
    name="$(awk '{print $2}' <<<"$line")"

    if [[ $prefix == '#' ]]; then
      dir="output/$name"
    elif [ ${#prefix} -eq ${last} ]; then
      dir="${dir%/*}/$name"
    elif [ ${#prefix} -lt ${last} ]; then
      dir="$(echo "$dir" | cut -d'/' -f1-$((${#prefix}+1)) )/$name"
      else
        dir="$dir/$name"
    fi
    last=${#prefix}
    echo "$dir"
  elif [[ $line =~ 'x$' ]]; then
    file="$(awk '{print $1}' <<<"$line")"
    echo "$dir/$file"
  fi
done
