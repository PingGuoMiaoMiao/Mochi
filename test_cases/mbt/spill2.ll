target triple = "riscv64-unknown-linux-gnu"

declare void @print_int(i32)
declare void @print_double(double)
declare void @print_endline()
declare i32 @int_of_float(double)
declare double @float_of_int(i32)
declare i32 @truncate(double)
declare double @abs_float(double)
declare i8* @malloc(i32)
declare i32 @minimbt_read_int()
declare i32 @minimbt_read_char()
declare void @minimbt_print_int(i32)
declare void @minimbt_print_endline()
declare void @minimbt_print_char(i32)
declare i32 @minimbt_int_of_float(double)
declare double @minimbt_float_of_int(i32)
declare i32 @minimbt_truncate(double)
declare i32 @minimbt_floor(double)
declare double @minimbt_abs_float(double)
declare double @minimbt_sqrt(double)
declare double @minimbt_sin(double)
declare double @minimbt_cos(double)
declare double @minimbt_atan(double)
declare i8* @minimbt_malloc(i32)
declare i32* @minimbt_create_array(i32, i32)
declare i8** @minimbt_create_ptr_array(i32, i8*)
declare double* @minimbt_create_float_array(i32, double)
declare i32 @minimbt_checked_add(i32, i32)
declare i32 @minimbt_checked_sub(i32, i32)
declare i32 @minimbt_checked_mul(i32, i32)
declare i32 @minimbt_checked_div(i32, i32)
declare void @mincaml_print_int(i32)
declare void @mincaml_print_endline()
declare i32 @mincaml_int_of_float(double)
declare double @mincaml_float_of_int(i32)
declare i32 @mincaml_truncate(double)
declare i32 @mincaml_floor(double)
declare double @mincaml_abs_float(double)
declare double @mincaml_sqrt(double)
declare double @mincaml_sin(double)
declare double @mincaml_cos(double)
declare double @mincaml_atan(double)
declare i8* @mincaml_malloc(i32)
declare i32* @mincaml_create_array(i32, i32)
declare i8** @mincaml_create_ptr_array(i32, i8*)
declare double* @mincaml_create_float_array(i32, double)


define i32 @f() {
entry:
  %t0 = add i32 0, 12345
  ret i32 %t0
}

define i32 @g(i32 %0) {
entry:
  %t0 = alloca i32
  store i32 %0, i32* %t0
  %t1 = load i32, i32* %t0
  %t2 = add i32 0, 1
  %t3 = add i32 %t1, %t2
  ret i32 %t3
}

define void @minimbt_main() {
entry:
  %t0 = add i32 0, 10
  %t1 = add i32 0, 1
  %t2 = call i32* @minimbt_create_array(i32 %t0, i32 %t1)
  %t3 = ptrtoint i32* %t2 to i32
  %t4 = alloca i32
  store i32 %t3, i32* %t4
  %t5 = call i32 @f()
  %t6 = alloca i32
  store i32 %t5, i32* %t6
  %t7 = add i32 0, 67890
  %t8 = alloca i32
  store i32 %t7, i32* %t8
  %t10 = add i32 0, 0
  %t11 = getelementptr i32, i32* %t4, i32 %t10
  %t12 = load i32, i32* %t11
  %t13 = alloca i32
  store i32 %t12, i32* %t13
  %t14 = load i32, i32* %t13
  %t15 = load i32, i32* %t13
  %t16 = add i32 %t14, %t15
  %t17 = alloca i32
  store i32 %t16, i32* %t17
  %t18 = load i32, i32* %t17
  %t19 = load i32, i32* %t17
  %t20 = add i32 %t18, %t19
  %t21 = alloca i32
  store i32 %t20, i32* %t21
  %t22 = load i32, i32* %t21
  %t23 = load i32, i32* %t21
  %t24 = add i32 %t22, %t23
  %t25 = alloca i32
  store i32 %t24, i32* %t25
  %t26 = load i32, i32* %t25
  %t27 = load i32, i32* %t25
  %t28 = add i32 %t26, %t27
  %t29 = alloca i32
  store i32 %t28, i32* %t29
  %t30 = load i32, i32* %t29
  %t31 = load i32, i32* %t29
  %t32 = add i32 %t30, %t31
  %t33 = alloca i32
  store i32 %t32, i32* %t33
  %t34 = load i32, i32* %t33
  %t35 = load i32, i32* %t33
  %t36 = add i32 %t34, %t35
  %t37 = alloca i32
  store i32 %t36, i32* %t37
  %t38 = load i32, i32* %t37
  %t39 = load i32, i32* %t37
  %t40 = add i32 %t38, %t39
  %t41 = alloca i32
  store i32 %t40, i32* %t41
  %t42 = load i32, i32* %t41
  %t43 = load i32, i32* %t41
  %t44 = add i32 %t42, %t43
  %t45 = alloca i32
  store i32 %t44, i32* %t45
  %t46 = load i32, i32* %t45
  %t47 = load i32, i32* %t45
  %t48 = add i32 %t46, %t47
  %t49 = alloca i32
  store i32 %t48, i32* %t49
  %t50 = load i32, i32* %t49
  %t51 = load i32, i32* %t49
  %t52 = add i32 %t50, %t51
  %t53 = alloca i32
  store i32 %t52, i32* %t53
  %t54 = load i32, i32* %t53
  %t55 = load i32, i32* %t53
  %t56 = add i32 %t54, %t55
  %t57 = alloca i32
  store i32 %t56, i32* %t57
  %t58 = load i32, i32* %t57
  %t59 = load i32, i32* %t57
  %t60 = add i32 %t58, %t59
  %t61 = alloca i32
  store i32 %t60, i32* %t61
  %t62 = load i32, i32* %t61
  %t63 = load i32, i32* %t61
  %t64 = add i32 %t62, %t63
  %t65 = alloca i32
  store i32 %t64, i32* %t65
  %t66 = load i32, i32* %t65
  %t67 = load i32, i32* %t65
  %t68 = add i32 %t66, %t67
  %t69 = alloca i32
  store i32 %t68, i32* %t69
  %t70 = load i32, i32* %t69
  %t71 = load i32, i32* %t69
  %t72 = add i32 %t70, %t71
  %t73 = alloca i32
  store i32 %t72, i32* %t73
  %t75 = add i32 0, 1
  %t76 = getelementptr i32, i32* %t4, i32 %t75
  %t77 = load i32, i32* %t76
  %t78 = add i32 0, 0
  %t80 = icmp eq i32 %t77, %t78
  %t79 = zext i1 %t80 to i32
  %t82 = icmp ne i32 %t79, 0
  br i1 %t82, label %label0, label %label1
label0:
  %t83 = load i32, i32* %t8
  %t84 = call i32 @g(i32 %t83)
  br label %label2
label1:
  %t85 = load i32, i32* %t13
  %t86 = load i32, i32* %t17
  %t87 = add i32 %t85, %t86
  %t88 = load i32, i32* %t21
  %t89 = add i32 %t87, %t88
  %t90 = load i32, i32* %t25
  %t91 = add i32 %t89, %t90
  %t92 = load i32, i32* %t29
  %t93 = add i32 %t91, %t92
  %t94 = load i32, i32* %t33
  %t95 = add i32 %t93, %t94
  %t96 = load i32, i32* %t37
  %t97 = add i32 %t95, %t96
  %t98 = load i32, i32* %t41
  %t99 = add i32 %t97, %t98
  %t100 = load i32, i32* %t45
  %t101 = add i32 %t99, %t100
  %t102 = load i32, i32* %t49
  %t103 = add i32 %t101, %t102
  %t104 = load i32, i32* %t53
  %t105 = add i32 %t103, %t104
  %t106 = load i32, i32* %t57
  %t107 = add i32 %t105, %t106
  %t108 = load i32, i32* %t61
  %t109 = add i32 %t107, %t108
  %t110 = load i32, i32* %t65
  %t111 = add i32 %t109, %t110
  %t112 = load i32, i32* %t69
  %t113 = add i32 %t111, %t112
  %t114 = load i32, i32* %t73
  %t115 = add i32 %t113, %t114
  %t116 = load i32, i32* %t6
  %t117 = add i32 %t115, %t116
  br label %label2
label2:
  %t81 = phi i32 [ %t84, %label0 ], [ %t117, %label1 ]
  call void @minimbt_print_int(i32 %t81)
  %t118 = add i32 0, 0
  ret void
}

