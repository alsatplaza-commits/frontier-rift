class_name Ed25519
extends RefCounted

## RFC 8032 Ed25519 verify (TweetNaCl field arithmetic). No private key lives here.

class U64:
	var hi: int
	var lo: int

	func _init(h: int = 0, l: int = 0) -> void:
		hi = h & 0xFFFFFFFF
		lo = l & 0xFFFFFFFF


const _IV := [
	[0x6a09e667, 0xf3bcc908], [0xbb67ae85, 0x84caa73b],
	[0x3c6ef372, 0xfe94f82b], [0xa54ff53a, 0x5f1d36f1],
	[0x510e527f, 0xade682d1], [0x9b05688c, 0x2b3e6c1f],
	[0x1f83d9ab, 0xfb41bd6b], [0x5be0cd19, 0x137e2179],
]

const _K := [
	[0x428a2f98, 0xd728ae22], [0x71374491, 0x23ef65cd], [0xb5c0fbcf, 0xec4d3b2f], [0xe9b5dba5, 0x8189dbbc],
	[0x3956c25b, 0xf348b538], [0x59f111f1, 0xb605d019], [0x923f82a4, 0xaf194f9b], [0xab1c5ed5, 0xda6d8118],
	[0xd807aa98, 0xa3030242], [0x12835b01, 0x45706fbe], [0x243185be, 0x4ee4b28c], [0x550c7dc3, 0xd5ffb4e2],
	[0x72be5d74, 0xf27b896f], [0x80deb1fe, 0x3b1696b1], [0x9bdc06a7, 0x25c71235], [0xc19bf174, 0xcf692694],
	[0xe49b69c1, 0x9ef14ad2], [0xefbe4786, 0x384f25e3], [0x0fc19dc6, 0x8b8cd5b5], [0x240ca1cc, 0x77ac9c65],
	[0x2de92c6f, 0x592b0275], [0x4a7484aa, 0x6ea6e483], [0x5cb0a9dc, 0xbd41fbd4], [0x76f988da, 0x831153b5],
	[0x983e5152, 0xee66dfab], [0xa831c66d, 0x2db43210], [0xb00327c8, 0x98fb213f], [0xbf597fc7, 0xbeef0ee4],
	[0xc6e00bf3, 0x3da88fc2], [0xd5a79147, 0x930aa725], [0x06ca6351, 0xe003826f], [0x14292967, 0x0a0e6e70],
	[0x27b70a85, 0x46d22ffc], [0x2e1b2138, 0x5c26c926], [0x4d2c6dfc, 0x5ac42aed], [0x53380d13, 0x9d95b3df],
	[0x650a7354, 0x8baf63de], [0x766a0abb, 0x3c77b2a8], [0x81c2c92e, 0x47edaee6], [0x92722c85, 0x1482353b],
	[0xa2bfe8a1, 0x4cf10364], [0xa81a664b, 0xbc423001], [0xc24b8b70, 0xd0f89791], [0xc76c51a3, 0x0654be30],
	[0xd192e819, 0xd6ef5218], [0xd6990624, 0x5565a910], [0xf40e3585, 0x5771202a], [0x106aa070, 0x32bbd1b8],
	[0x19a4c116, 0xb8d2d0c8], [0x1e376c08, 0x5141ab53], [0x2748774c, 0xdf8eeb99], [0x34b0bcb5, 0xe19b48a8],
	[0x391c0cb3, 0xc5c95a63], [0x4ed8aa4a, 0xe3418acb], [0x5b9cca4f, 0x7763e373], [0x682e6ff3, 0xd6b2b8a3],
	[0x748f82ee, 0x5defb2fc], [0x78a5636f, 0x43172f60], [0x84c87814, 0xa1f0ab72], [0x8cc70208, 0x1a6439ec],
	[0x90befffa, 0x23631e28], [0xa4506ceb, 0xde82bde9], [0xbef9a3f7, 0xb2c67915], [0xc67178f2, 0xe372532b],
	[0xca273ece, 0xea26619c], [0xd186b8c7, 0x21c0c207], [0xeada7dd6, 0xcde0eb1e], [0xf57d4f7f, 0xee6ed178],
	[0x06f067aa, 0x72176fba], [0x0a637dc5, 0xa2c898a6], [0x113f9804, 0xbef90dae], [0x1b710b35, 0x131c471b],
	[0x28db77f5, 0x23047d84], [0x32caab7b, 0x40c72493], [0x3c9ebe0a, 0x15c9bebc], [0x431d67c4, 0x9c100d4c],
	[0x4cc5d4be, 0xcb3e42b6], [0x597f299c, 0xfc657e2a], [0x5fcb6fab, 0x3ad6faec], [0x6c44198c, 0x4a475817],
]

const _L := [0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10]
const _D := [0x78a3, 0x1359, 0x4dca, 0x75eb, 0xd8ab, 0x4141, 0x0a4d, 0x0070, 0xe898, 0x7779, 0x4079, 0x8cc7, 0xfe73, 0x2b6f, 0x6cee, 0x5203]
const _D2 := [0xf159, 0x26b2, 0x9b94, 0xebd6, 0xb156, 0x8283, 0x149a, 0x00e0, 0xd130, 0xeef3, 0x80f2, 0x198e, 0xfce7, 0x56df, 0xd9dc, 0x2406]
const _X := [0xd51a, 0x8f25, 0x2d60, 0xc956, 0xa7b2, 0x9525, 0xc760, 0x692c, 0xdc5c, 0xfdd6, 0xe231, 0xc0a4, 0x53fe, 0xcd6e, 0x36d3, 0x2169]
const _Y := [0x6658, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666]
const _I := [0xa0b0, 0x4a0e, 0x1b27, 0xc4ee, 0xe478, 0xad2f, 0x1806, 0x2f43, 0xd7a7, 0x3dfb, 0x0099, 0x2b4d, 0xdf0b, 0x4fc1, 0x2480, 0x2b83]


static func verify(public_key: PackedByteArray, signature: PackedByteArray, message: PackedByteArray) -> bool:
	if public_key.size() != 32 or signature.size() != 64:
		return false
	var sm := PackedByteArray()
	sm.resize(64 + message.size())
	for i in 64:
		sm[i] = signature[i]
	for i in message.size():
		sm[64 + i] = message[i]
	return _sign_open(sm, public_key)


static func sha512(message: PackedByteArray) -> PackedByteArray:
	var bit_len := message.size() * 8
	var data := message.duplicate()
	data.append(0x80)
	while (data.size() % 128) != 112:
		data.append(0)
	for _i in 8:
		data.append(0)
	for i in range(7, -1, -1):
		data.append((bit_len >> (i * 8)) & 0xFF)
	var h: Array = []
	for iv in _IV:
		h.append(U64.new(iv[0], iv[1]))
	var offset := 0
	while offset < data.size():
		var w: Array = []
		w.resize(80)
		for i in 16:
			w[i] = _load_be(data, offset + i * 8)
		for i in range(16, 80):
			w[i] = _add4(_sigma1(w[i - 2]), w[i - 7], _sigma0(w[i - 15]), w[i - 16])
		var a: U64 = h[0]
		var b: U64 = h[1]
		var c: U64 = h[2]
		var d: U64 = h[3]
		var e: U64 = h[4]
		var f: U64 = h[5]
		var g: U64 = h[6]
		var hh: U64 = h[7]
		for i in 80:
			var k := U64.new(_K[i][0], _K[i][1])
			var t1 := _add5(hh, _Sigma1(e), _ch(e, f, g), k, w[i])
			var t2 := _add2(_Sigma0(a), _maj(a, b, c))
			hh = g
			g = f
			f = e
			e = _add2(d, t1)
			d = c
			c = b
			b = a
			a = _add2(t1, t2)
		h[0] = _add2(h[0], a)
		h[1] = _add2(h[1], b)
		h[2] = _add2(h[2], c)
		h[3] = _add2(h[3], d)
		h[4] = _add2(h[4], e)
		h[5] = _add2(h[5], f)
		h[6] = _add2(h[6], g)
		h[7] = _add2(h[7], hh)
		offset += 128
	var out := PackedByteArray()
	out.resize(64)
	for i in 8:
		_store_be(out, i * 8, h[i])
	return out


static func _sign_open(sm: PackedByteArray, pk: PackedByteArray) -> bool:
	var n := sm.size()
	if n < 64:
		return false
	var q: Array = [_gf(), _gf(), _gf(), _gf()]
	if _unpackneg(q, pk) != 0:
		return false
	var m := PackedByteArray()
	m.resize(n)
	for i in n:
		m[i] = sm[i]
	for i in 32:
		m[32 + i] = pk[i]
	var h := sha512(m)
	_reduce(h)
	var p: Array = [_gf(), _gf(), _gf(), _gf()]
	_scalarmult(p, q, h)
	_scalarbase(q, sm, 32)
	_add(p, q)
	var t := PackedByteArray()
	t.resize(32)
	_pack(t, p)
	for i in 32:
		if int(sm[i]) != int(t[i]):
			return false
	return true


static func _floor_div(n: int, d: int) -> int:
	var q := int(n / d)
	var r := n - q * d
	if r != 0 and ((n < 0) != (d < 0)):
		q -= 1
	return q


static func _gf(init: Array = []) -> Array:
	var r: Array = []
	r.resize(16)
	for i in 16:
		r[i] = 0
	for i in init.size():
		r[i] = init[i]
	return r


static func _copy(a: Array) -> Array:
	var r := _gf()
	for i in 16:
		r[i] = int(a[i])
	return r


static func _assign(r: Array, a: Array) -> void:
	for i in 16:
		r[i] = int(a[i])


static func _car(o: Array) -> void:
	for i in 16:
		o[i] = int(o[i]) + 65536
		var c := _floor_div(int(o[i]), 65536)
		var idx := 0 if i == 15 else i + 1
		var addend := c - 1
		if i == 15:
			addend += 37 * (c - 1)
		o[idx] = int(o[idx]) + addend
		o[i] = int(o[i]) - c * 65536


static func _sel(p: Array, q: Array, b: int) -> void:
	var c := ~(b - 1)
	for i in 16:
		var t := c & (int(p[i]) ^ int(q[i]))
		p[i] = int(p[i]) ^ t
		q[i] = int(q[i]) ^ t


static func _pack25519(o: PackedByteArray, n: Array) -> void:
	var t := _copy(n)
	_car(t)
	_car(t)
	_car(t)
	for _j in 2:
		var m := _gf()
		m[0] = int(t[0]) - 0xffed
		for i in range(1, 15):
			m[i] = int(t[i]) - 0xffff - ((int(m[i - 1]) >> 16) & 1)
			m[i - 1] = int(m[i - 1]) & 0xffff
		m[15] = int(t[15]) - 0x7fff - ((int(m[14]) >> 16) & 1)
		var b := (int(m[15]) >> 16) & 1
		m[14] = int(m[14]) & 0xffff
		_sel(t, m, 1 - b)
	for i in 16:
		o[2 * i] = int(t[i]) & 0xff
		o[2 * i + 1] = (int(t[i]) >> 8) & 0xff


static func _unpack25519(o: Array, n: PackedByteArray) -> void:
	for i in 16:
		o[i] = int(n[2 * i]) + (int(n[2 * i + 1]) << 8)
	o[15] = int(o[15]) & 0x7fff


static func _neq(a: Array, b: Array) -> bool:
	var c := PackedByteArray()
	var d := PackedByteArray()
	c.resize(32)
	d.resize(32)
	_pack25519(c, a)
	_pack25519(d, b)
	for i in 32:
		if int(c[i]) != int(d[i]):
			return true
	return false


static func _par(a: Array) -> int:
	var d := PackedByteArray()
	d.resize(32)
	_pack25519(d, a)
	return int(d[0]) & 1


static func _A(o: Array, a: Array, b: Array) -> void:
	for i in 16:
		o[i] = int(a[i]) + int(b[i])


static func _Z(o: Array, a: Array, b: Array) -> void:
	for i in 16:
		o[i] = int(a[i]) - int(b[i])


static func _M(o: Array, a: Array, b: Array) -> void:
	var t: Array = []
	t.resize(31)
	for i in 31:
		t[i] = 0
	for i in 16:
		for j in 16:
			t[i + j] = int(t[i + j]) + int(a[i]) * int(b[j])
	for i in 15:
		t[i] = int(t[i]) + 38 * int(t[i + 16])
	for i in 16:
		o[i] = t[i]
	_car(o)
	_car(o)


static func _S(o: Array, a: Array) -> void:
	_M(o, a, a)


static func _inv(o: Array, i: Array) -> void:
	var c := _copy(i)
	for a in range(253, -1, -1):
		_S(c, c)
		if a != 2 and a != 4:
			_M(c, c, i)
	_assign(o, c)


static func _pow2523(o: Array, i: Array) -> void:
	var c := _copy(i)
	for a in range(250, -1, -1):
		_S(c, c)
		if a != 1:
			_M(c, c, i)
	_assign(o, c)


static func _add(p: Array, q: Array) -> void:
	var a := _gf()
	var b := _gf()
	var c := _gf()
	var d := _gf()
	var e := _gf()
	var f := _gf()
	var g := _gf()
	var h := _gf()
	var t := _gf()
	_Z(a, p[1], p[0])
	_Z(t, q[1], q[0])
	_M(a, a, t)
	_A(b, p[0], p[1])
	_A(t, q[0], q[1])
	_M(b, b, t)
	_M(c, p[3], q[3])
	_M(c, c, _gf(_D2))
	_M(d, p[2], q[2])
	_A(d, d, d)
	_Z(e, b, a)
	_Z(f, d, c)
	_A(g, d, c)
	_A(h, b, a)
	_M(p[0], e, f)
	_M(p[1], h, g)
	_M(p[2], g, f)
	_M(p[3], e, h)


static func _cswap(p: Array, q: Array, b: int) -> void:
	for i in 4:
		_sel(p[i], q[i], b)


static func _pack(r: PackedByteArray, p: Array) -> void:
	var tx := _gf()
	var ty := _gf()
	var zi := _gf()
	_inv(zi, p[2])
	_M(tx, p[0], zi)
	_M(ty, p[1], zi)
	_pack25519(r, ty)
	r[31] = int(r[31]) ^ (_par(tx) << 7)


static func _scalarmult(p: Array, q: Array, s: PackedByteArray) -> void:
	_assign(p[0], _gf())
	_assign(p[1], _gf([1]))
	_assign(p[2], _gf([1]))
	_assign(p[3], _gf())
	for i in range(255, -1, -1):
		var b := (int(s[int(i / 8)]) >> (i & 7)) & 1
		_cswap(p, q, b)
		_add(q, p)
		_add(p, p)
		_cswap(p, q, b)


static func _scalarbase(p: Array, s: PackedByteArray, offset: int) -> void:
	var q: Array = [_gf(), _gf(), _gf(), _gf()]
	_assign(q[0], _gf(_X))
	_assign(q[1], _gf(_Y))
	_assign(q[2], _gf([1]))
	_M(q[3], q[0], q[1])
	var scalar := PackedByteArray()
	scalar.resize(64)
	for i in 32:
		var idx := offset + i
		scalar[i] = s[idx] if idx < s.size() else 0
	_scalarmult(p, q, scalar)


static func _modL(r: PackedByteArray, x: Array) -> void:
	var carry := 0
	for i in range(63, 31, -1):
		carry = 0
		var j := i - 32
		var k := i - 12
		while j < k:
			x[j] = int(x[j]) + carry - 16 * int(x[i]) * int(_L[j - (i - 32)])
			carry = _floor_div(int(x[j]) + 128, 256)
			x[j] = int(x[j]) - carry * 256
			j += 1
		x[j] = int(x[j]) + carry
		x[i] = 0
	carry = 0
	for j in 32:
		x[j] = int(x[j]) + carry - ((int(x[31]) >> 4) * int(_L[j]))
		carry = int(x[j]) >> 8
		x[j] = int(x[j]) & 255
	for j in 32:
		x[j] = int(x[j]) - carry * int(_L[j])
	for i in 32:
		x[i + 1] = int(x[i + 1]) + (int(x[i]) >> 8)
		r[i] = int(x[i]) & 255


static func _reduce(r: PackedByteArray) -> void:
	var x: Array = []
	x.resize(64)
	for i in 64:
		x[i] = int(r[i])
	for i in 64:
		r[i] = 0
	_modL(r, x)


static func _unpackneg(r: Array, p: PackedByteArray) -> int:
	var t := _gf()
	var chk := _gf()
	var num := _gf()
	var den := _gf()
	var den2 := _gf()
	var den4 := _gf()
	var den6 := _gf()
	_assign(r[2], _gf([1]))
	_unpack25519(r[1], p)
	_S(num, r[1])
	_M(den, num, _gf(_D))
	_Z(num, num, r[2])
	_A(den, r[2], den)
	_S(den2, den)
	_S(den4, den2)
	_M(den6, den4, den2)
	_M(t, den6, num)
	_M(t, t, den)
	_pow2523(t, t)
	_M(t, t, num)
	_M(t, t, den)
	_M(t, t, den)
	_M(r[0], t, den)
	_S(chk, r[0])
	_M(chk, chk, den)
	if _neq(chk, num):
		_M(r[0], r[0], _gf(_I))
	_S(chk, r[0])
	_M(chk, chk, den)
	if _neq(chk, num):
		return -1
	if _par(r[0]) == ((int(p[31]) >> 7) & 1):
		_Z(r[0], _gf(), r[0])
	_M(r[3], r[0], r[1])
	return 0


static func _add2(a: U64, b: U64) -> U64:
	return _add4(a, b, U64.new(0, 0), U64.new(0, 0))


static func _add4(a: U64, b: U64, c: U64, d: U64) -> U64:
	return _add5(a, b, c, d, U64.new(0, 0))


static func _add5(a: U64, b: U64, c: U64, d: U64, e: U64) -> U64:
	var lo := a.lo + b.lo + c.lo + d.lo + e.lo
	var hi := a.hi + b.hi + c.hi + d.hi + e.hi + (lo >> 32)
	return U64.new(hi, lo)


static func _rotr(x: U64, c: int) -> U64:
	c = c % 64
	if c == 0:
		return U64.new(x.hi, x.lo)
	if c == 32:
		return U64.new(x.lo, x.hi)
	if c > 32:
		return _rotr(U64.new(x.lo, x.hi), c - 32)
	var rhi := ((x.hi >> c) | (x.lo << (32 - c))) & 0xFFFFFFFF
	var rlo := ((x.lo >> c) | (x.hi << (32 - c))) & 0xFFFFFFFF
	return U64.new(rhi, rlo)


static func _shr(x: U64, c: int) -> U64:
	if c <= 0:
		return U64.new(x.hi, x.lo)
	if c >= 64:
		return U64.new(0, 0)
	if c == 32:
		return U64.new(0, x.hi)
	if c > 32:
		return U64.new(0, x.hi >> (c - 32))
	var rhi := x.hi >> c
	var rlo := ((x.lo >> c) | (x.hi << (32 - c))) & 0xFFFFFFFF
	return U64.new(rhi, rlo)


static func _xor3(a: U64, b: U64, c: U64) -> U64:
	return U64.new(a.hi ^ b.hi ^ c.hi, a.lo ^ b.lo ^ c.lo)


static func _ch(x: U64, y: U64, z: U64) -> U64:
	var nhi := (~x.hi) & 0xFFFFFFFF
	var nlo := (~x.lo) & 0xFFFFFFFF
	return U64.new((x.hi & y.hi) ^ (nhi & z.hi), (x.lo & y.lo) ^ (nlo & z.lo))


static func _maj(x: U64, y: U64, z: U64) -> U64:
	return U64.new((x.hi & y.hi) ^ (x.hi & z.hi) ^ (y.hi & z.hi), (x.lo & y.lo) ^ (x.lo & z.lo) ^ (y.lo & z.lo))


static func _Sigma0(x: U64) -> U64:
	return _xor3(_rotr(x, 28), _rotr(x, 34), _rotr(x, 39))


static func _Sigma1(x: U64) -> U64:
	return _xor3(_rotr(x, 14), _rotr(x, 18), _rotr(x, 41))


static func _sigma0(x: U64) -> U64:
	return _xor3(_rotr(x, 1), _rotr(x, 8), _shr(x, 7))


static func _sigma1(x: U64) -> U64:
	return _xor3(_rotr(x, 19), _rotr(x, 61), _shr(x, 6))


static func _load_be(data: PackedByteArray, pos: int) -> U64:
	var hi := 0
	var lo := 0
	for i in 4:
		hi = (hi << 8) | int(data[pos + i])
		lo = (lo << 8) | int(data[pos + 4 + i])
	return U64.new(hi, lo)


static func _store_be(out: PackedByteArray, pos: int, v: U64) -> void:
	for i in 4:
		out[pos + i] = (v.hi >> ((3 - i) * 8)) & 0xFF
		out[pos + 4 + i] = (v.lo >> ((3 - i) * 8)) & 0xFF
