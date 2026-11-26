#!/usr/bin/env sh
# T-285: fetch one Higgsfield result into build/trailers/hf/<shot>.mp4 and make <shot>_cmp.jpg: four frames of the
# in-engine source (top) over the same moments of the re-render (bottom), for the rule check.
#   tools/trailer/hf_fetch.sh <shot> <url> [suffix]
cd "$(dirname "$0")/../.." || exit 2
k=$1; u=$2; s=${3:-}
o=build/trailers/hf/$k$s.mp4; w=build/trailers/src/teaser_m0/$k.mp4
[ -s "$o" ] || curl -s -o "$o" "$u"
d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$o"); wd=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$w" 2>/dev/null || echo "$d")
echo "$k$s real=$d wire=$wd"
args=""; i=0
for p in 0.05 0.35 0.65 0.95; do
  ffmpeg -y -v error -ss $(awk "BEGIN{print $wd*$p}") -i "$w" -frames:v 1 -vf scale=427:240 build/trailers/hf/_w$i.png 2>/dev/null || ffmpeg -y -v error -f lavfi -i color=black:s=427x240 -frames:v 1 build/trailers/hf/_w$i.png
  ffmpeg -y -v error -ss $(awk "BEGIN{print $d*$p}") -i "$o" -frames:v 1 -vf scale=427:240 build/trailers/hf/_r$i.png
  i=$((i+1))
done
ffmpeg -y -v error -i build/trailers/hf/_w0.png -i build/trailers/hf/_w1.png -i build/trailers/hf/_w2.png -i build/trailers/hf/_w3.png \
  -i build/trailers/hf/_r0.png -i build/trailers/hf/_r1.png -i build/trailers/hf/_r2.png -i build/trailers/hf/_r3.png \
  -filter_complex "[0][1][2][3]hstack=4[a];[4][5][6][7]hstack=4[b];[a][b]vstack" build/trailers/hf/${k}${s}_cmp.jpg
