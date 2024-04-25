#!/bin/bash

function cut_head() {
	SOURCE="$1"
	TARGET="$2"

	TITLE=`grep '^title = ' "${SOURCE}" | cut -d ' ' -f '3-' | sed -e 's/"//g'`

	echo "# ${TITLE}" > "${TARGET}"
	echo "" >> "${TARGET}"

    N=`grep -n '^+++' "${SOURCE}" | cut -d ':' -f 1 | tail -1`
	N=$(($N + 1))
	tail -n "+${N}" "${SOURCE}" >> "${TARGET}"
}

LST=`find content/docs/ -name "*.md" | grep -v "_index.md"`

rm -rf mdbook
mkdir mdbook
mkdir mdbook/src

for F in $LST; do
	SOURCE="$F"
	FN=`basename "${SOURCE}"`
	TARGET="mdbook/src/${FN}"
	cut_head "${SOURCE}" "${TARGET}"
done

cp SUMMARY.md mdbook/src/

mdbook build mdbook/


