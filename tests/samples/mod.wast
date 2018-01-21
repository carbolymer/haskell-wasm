(module

  (func $foo (result i32) (i32.const 0))

  (func f
    (i32.const 0)
    (i32.const -2147483648)
    (i32.const 4294967295)
    (i32.const -0x80000000)
    (i32.const 0xffffffff)

    (i64.const 0)
    (i64.const -9223372036854775808)
    (i64.const 18446744073709551615)
    (i64.const -0x8000000000000000)
    (i64.const 0xffffffffffffffff)
  )

  (func $add (param $x f32) (param $y f32) (result f32) (f32.add (get_local $x) (get_local $y)))
  (func $sub (param $x f32) (param $y f32) (result f32) (f32.sub (get_local $x) (get_local $y)))
  (func $mul (param $x f32) (param $y f32) (result f32) (f32.mul (get_local $x) (get_local $y)))
  (func $div (param $x f32) (param $y f32) (result f32) (f32.div (get_local $x) (get_local $y)))
  (func $sqrt (param $x f32) (result f32) (f32.sqrt (get_local $x)))
  (func $min (param $x f32) (param $y f32) (result f32) (f32.min (get_local $x) (get_local $y)))
  (func $max (param $x f32) (param $y f32) (result f32) (f32.max (get_local $x) (get_local $y)))
  (func $ceil (param $x f32) (result f32) (f32.ceil (get_local $x)))
  (func $floor (param $x f32) (result f32) (f32.floor (get_local $x)))
  (func $trunc (param $x f32) (result f32) (f32.trunc (get_local $x)))
  (func $nearest (param $x f32) (result f32) (f32.nearest (get_local $x)))
  (func $abs (param $x f32) (result f32) (f32.abs (get_local $x)))
  (func $neg (param $x f32) (result f32) (f32.neg (get_local $x)))
  (func $copysign (param $x f32) (param $y f32) (result f32) (f32.copysign (get_local $x) (get_local $y)))

  (func f (param x i64) (result i64)
  
    (if_else (i64.eq (get_local 0) (i64.const 0))
      (i64.const 1)
      (i64.mul (get_local 0) (call 0 (i64.sub (get_local 0) (i64.const 1))))
    )

  )

  (func $fac-rec (param $n i64) (result i64)
    (if_else (i64.eq (get_local $n) (i64.const 0))
      (i64.const 1)
      (i64.mul
        (get_local $n)
        (call $fac-rec (i64.sub (get_local $n) (i64.const 1)))
      )
    )
  )

  (func f (param a i64) (result i64)
    (set_local 1 (get_local 0))
    (set_local 2 (i64.const 1))
    (block
      (loop
        (if_else
          (i64.eq (get_local 1) (i64.const 0))
          (br 1)
          (block
            (set_local 2 (i64.mul (get_local 1) (get_local 2)))
            (set_local 1 (i64.sub (get_local 1) (i64.const 1)))
          )
        )
        (br 0)
      )
    )
    (return (get_local 2))
  )

  ;; foo
  (func f (param i64) (result i64)
    (set_local 1 (get_local 0))
    (set_local 2 (i64.const 1))
    (block
      (loop
        (if_else
          (i64.eq (get_local 1) (i64.const 0))
          (br 1)
          (block
            (set_local 2 (i64.mul (get_local 1) (get_local 2)))
            (set_local 1 (i64.sub (get_local 1) (i64.const 1)))
          )
        )
        (br 0)
      )
    )
    (return (get_local 2))
  )


)