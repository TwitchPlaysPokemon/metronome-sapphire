#!node
const MAX_CARDS = 52;
const SCENE_CHANGES = 9;
const OUTFILE = '../../src/data/credits_custom.h';

const fs = require('fs');

const credits = require('./credits_text');

const strids = new Map();
let multiColumnMode = false;

// Verify json, collect unique names
let _i = 0;
if (!Array.isArray(credits)) {
	console.error("Credits object is not an array!");
	return -1;
}
if (credits.length != MAX_CARDS) {
	console.error(`Credits array has the wrong number of cards! (${credits.length} != ${MAX_CARDS})`);
	return -1;
}
for (let card of credits) {
	if (!Array.isArray(credits)) {
		console.error(`Cards must be an array! (Card ${_i})`);
		return -1;
	}
	if (card.length > 5) {
		console.error(`Cards can have no more than 5 lines! (Card ${_i})`);
		return -1;
	}
	for (let line of card) {
		if (Array.isArray(line)) {
			if (line.length > 2) {
				console.error(`Lines cannot have more than two names in an array! (Card ${_i})`);
				return -1;
			}
			multiColumnMode = true;
		} else if (typeof line === 'object') {
			if (!line.id || !line.ruby || !line.sapphire) {
				console.error(`Object lines must have an 'id', a 'ruby', and a 'sapphire' key! (Card ${_i})`);
				return -1;
			}
		}
	}
	_i++;
}

let strings = [`static const u8 gCreditsText_EmptyString[] = _("");`];
let entries = [`static const struct CreditsEntry gCreditsEntry_EmptyString[] = {0, gCreditsText_EmptyString};`];
let array = [];

function makeText(str, id = undefined) {
	let defstr, defentry;
	let title = false;
	if (str.startsWith('#')) {
		title = true;
		str = str.slice(1);
	}
	str = str.replace(/_/g, " "); //Credits can't have underscores
	let strid = strids.get(id || str);
	if (!strid) {
		strid = id || str;
		strid = strid.replace(/POKéMON/ig, 'Pkmn');
		strid = strid.replace(/[^a-zA-Z0-9]/gi, '');
		strids.set(str, strid);
		defstr = `static const u8 gCreditsText_${strid}[] = _("${title ? '{PALETTE 9}' : ''}${str}");`;
		defentry = `static const struct CreditsEntry gCreditsEntry_${strid}[] = {0, gCreditsText_${strid}};`;
	}
	return [`gCreditsEntry_${strid}`, defstr, defentry];
}

for (const incard of credits) {
	let card = new Array(multiColumnMode ? 10 : 5);
	switch (incard.length) {
		case 0:
			card[1] = `#Unused Card ${array.length}`;
			break;
		case 3:
			card[3] = incard[2];
		// fallthrough
		case 2:
			card[2] = incard[1];
		// fallthrough
		case 1:
			card[1] = incard[0];
			break;
		case 5:
			card[4] = incard[4];
		// fallthrough
		case 4:
			card[0] = incard[0];
			card[1] = incard[1];
			card[2] = incard[2];
			card[3] = incard[3];
			break;
	}
	if (multiColumnMode) {
		for (let i = 0; i < 5; i++) {
			if (Array.isArray(card[i])) {
				card[i + 5] = card[i][1];
				card[i] = card[i][0];
			}
		}
	}
	for (let i = 0; i < card.length; i++) {
		if (!card[i]) {
			if (card[i] === "") card[i] = "_";
			else card[i] = i < 5 ? "_" : "NULL";
		} else if (typeof card[i] === 'object') {
			let c, s, e;
			[c, s, e] = makeText(card[i].sapphire, card[i].id);
			if (s) strings.push(`#ifdef SAPPHIRE`, s);
			if (e) entries.push(e);

			[c, s, e] = makeText(card[i].ruby, card[i].id);
			if (s) strings.push(`#else`, s, `#endif`);
			card[i] = c;
		} else if (typeof card[i] === 'string') {
			let [c, s, e] = makeText(card[i]);
			card[i] = c;
			if (s) strings.push(s);
			if (e) entries.push(e);
		}
	}
	array.push(card);
}


let out;
try {
	out = fs.createWriteStream(OUTFILE);
	if (multiColumnMode) {
		out.write(`#define MULTI_COLUMN_MODE\n`);
	}
	out.write(strings.join('\n'));
	out.write('\n');
	out.write(entries.join('\n'));
	out.write(`\n
#define _ gCreditsEntry_EmptyString
static const struct CreditsEntry *const gCreditsEntryPointerTable[][${multiColumnMode ? 10 : 5}] =
{\n`);
	for (let card of array) {
		out.write(`\t{\n`);
		for (let line of card) {
			out.write(`\t\t${line},\n`);
		}
		out.write(`\t},\n`);
	}
	out.write(`};\n#undef _\n`);
	out.write(`\nenum {\n`);
	let changecard = 0;
	for (let i = 1; i < SCENE_CHANGES; i++) {
		// All scenes seem to expect 6 cards, except for two
		changecard += 6;
		if (i == 6 || i == 7) changecard--;
		// out.write(`\tSCENE_CHANGE_${i} = ${Math.ceil(i*(array.length/SCENE_CHANGES))},\n`);
		out.write(`\tSCENE_CHANGE_${i} = ${changecard},\n`);
	}
	out.write(`};\n`);
} finally {
	out.end();
}


