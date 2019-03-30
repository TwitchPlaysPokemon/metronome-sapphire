#!/bin/bash

sb1=pokesapphire_rev1.gba
sb2=pokesapphire_rev2.gba
starget=metronomesapphire.gba
output=metronomesapphire.bsp

function checkfail {
	$@
	local result=$?
	if [[ $result -eq 0 ]]; then
		return 0
	fi
	echo "[$1] exit status $result" >&2
	exit 3
}

function updaterepo {
	# $1: repo, $2: URL
	if [[ ! ( -d $1 ) ]]; then
		checkfail git clone --recursive $2 $1
	fi
	pushd $1
	git pull
	popd
}

function checkhash {
	# $1: file, $2: expected hash
	# returns a Bool: https://thedailywtf.com/articles/What_Is_Truth_0x3f_
	if [[ ! ( -f $1 ) ]]; then
		return 2
	fi
	[ `sha1sum -b $1 | cut -c 1-40` = $2 ]
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	return 0
}

function checksapphire {
	checkhash $sb1 4722efb8cd45772ca32555b98fd3b9719f8e60a9
	local check1=$?
	checkhash $sb2 89b45fb172e6b55d51fc0e61989775187f6fe63c
	local check2=$?
	if [[ $check2 -gt $check1 ]]; then
		return $check2
	else
		return $check1
	fi
}

function buildtarget {
	# $1 = file, $2 = make target
	if [[ -f $1 ]]; then
		return 0
	fi
	if [[ ! ( -f ../$1 ) ]]; then
		pushd ..
		checkfail make $2
		popd
	fi
	checkfail cp ../$1 .
}

# make sure the patch directory exists
if [[ ! ( -d patch-staging ) ]]; then
	checkfail mkdir patch-staging
fi
pushd patch-staging

# make sure we have a copy of bspbuild
if [[ ! ( -x bspbuild ) ]]; then
	updaterepo bspbuildrepo https://github.com/aaaaaa123456789/bspbuild.git
	pushd bspbuildrepo
	checkfail make
	checkfail cp bspbuild ..
	popd
fi

# update pokeruby if we don't have good base ROMs, and get agbcc too just in case
checksapphire
if [[ $? -ne 0 ]]; then
	updaterepo agbcc https://github.com/pret/agbcc
	updaterepo pokeruby https://github.com/pret/pokeruby.git
	pushd agbcc
	chmod 0755 install.sh
	chmod 0755 build.sh
	checkfail ./build.sh
	checkfail ./install.sh ../pokeruby
	cd ../pokeruby
	checkfail make sapphire_rev1 sapphire_rev2
	checkfail cp $sb1 ..
	checkfail cp $sb2 ..
	popd
	checksapphire
	case $? in
		0)
			;;
		1)
			echo "[check] base ROM hash mismatch" >&2
			exit 1
			;;
		2)
			echo "[check] base ROM not found" >&2
			exit 2
			;;
		*)
			echo "[check] unknown error" >&2
			exit 3
			;;
	esac
fi

# build the target file, and make sure we have a copy in the staging area
buildtarget $starget all

# build the patch
./bspbuild -m ips -s $sb1 $sb2 -m xor-rle -t $starget -o $output -p 0xffffffff --titles-from-stdin <<-END
	// base ROMs
	$sb1=Pokémon Sapphire (rev. 1)
	$sb2=Pokémon Sapphire (rev. 2)

	// target ROM
	$starget=TPP Pokémon Metronome Sapphire
END
result=$?
if [[ $result -ne 0 ]]; then
	echo "[bspbuild] exit status $result" >&2
	exit 3
fi

# copy the file to the parent directory and we're done
checkfail cp $output ..
popd
exit 0
