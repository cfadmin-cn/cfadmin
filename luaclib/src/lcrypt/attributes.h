/* attributes.h; some GCC extensions wrapped up so they do nothing elsewhere
 * Copyright 2009-2010 Rob Kendrick <rjek@rjek.com>, distributed under MIT
 *
 * Of course, some compilers define __GNUC__ and a GCC version number, and
 * aren't GCC.  If they choke when you use this file, report a bug to your
 * compiler vendor.
 */

#ifndef _GCC_ATTRIBUTES_
#define _GCC_ATTRIBUTES_

#ifdef __GNUC__
#	define GCC_VERSION (__GNUC__ * 10000 \
						+ __GNUC_MINOR__ * 100 \
						+ __GNUC_PATCHLEVEL__)
#else
#	define GCC_VERSION 0
#endif

/* Symbol behaviors *********************************************************/

#if GCC_VERSION >= 20500
#	define _NORETURN __attribute__ ((noreturn))
#else
#	define _NORETURN
#endif

#if GCC_VERSION >= 20700
#	define _CONSTRUCTOR __attribute__ ((constructor))
#	define _DESTRUCTOR __attribute__ ((destructor))
#	define _WEAK __attribute__ ((weak))
#else
#	define _CONSTRUCTOR
#	define _DESTRUCTOR
#	define _WEAK
#endif

#if GCC_VERSION >= 30000
#	define _MALLOC __attribute__ ((malloc))
#else
#	define _MALLOC
#endif

#if GCC_VERSION >= 30300
#	define _CLEANUP(x) __attribute__ ((cleanup(x)))
#else
#	define _CLEANUP(x)
#endif

/* Parameter and call checking **********************************************/

#if GCC_VERSION >= 20300
#	define _FORMAT(...) __attribute__ ((format(__VA_ARGS__)))
#else
#	define _FORMAT(...)
#endif

#if GCC_VERSION >= 20700
#	define _UNUSED __attribute__ ((unused))
#else
#	define _UNUSED
#endif

#if GCC_VERSION >= 20800
#	define _FORMAT_ARG(x) __attribute__ ((format_arg(x)))
#else
#	define _FORMAT_ARG(x)
#endif

#if GCC_VERSION >= 30100
#	define _DEPRECATED __attribute__ ((deprecated))
#	define _USED __attribute__ ((used))
#else
#	define _DEPRECATED
#	define _USED
#endif

#if GCC_VERSION >= 30300
#	define _NONNULL(...) __attribute__ ((nonnull(__VA_ARGS__)))
#	define _WARN_UNUSED_RESULT __attribute__ ((warn_unused_result))
#else
#	define _NONNULL(...)
#	define _WARN_UNUSED_RESULT
#endif

#if GCC_VERSION >= 40400
#       define _BOUNDED(...) __attribute ((__bounded__(__VAR_ARGS__)))
#else
#       define _BOUNDED(...)
#endif

/* Performance and optimisation-related *************************************/

#if GCC_VERSION >= 20500
#	define _CONST __attribute__ ((const))
#else
#	define _CONST
#endif

#if GCC_VERSION >= 20700
#	define _ALIGNED(x) __attribute__ ((aligned(x)))
#	define _PACKED __attribute__ ((packed))
#else
#	define _ALIGNED(x)
#	define _PACKED
#endif

#if GCC_VERSION >= 30000
#	define _PURE __attribute__ ((pure))
#else
#	define _PURE
#endif

#if GCC_VERSION >= 30100
#	define _NO_INLINE __attribute__ ((noinline))
#else
#	define _NO_INLINE
#endif

#if GCC_VERSION >= 30200
#	define _NOTHROW __attribute__ ((nothrow))
#else
#	define _NOTHROW
#endif

#if GCC_VERSION >= 40300
#	define _HOT __attribute__ ((hot))
#	define _COLD __attribute__ ((cold))
#else
#	define _HOT
#	define _COLD
#endif

#if GCC_VERSION >= 40400
#	define _OPTIMISE(x) __attribute__ ((optimize(x)))
#	define _TARGET(x) __attribute__ ((target(x)))
#	define _SSEREGPARM __attribute__ ((sseregparm))
#else
#	define _OPTIMISE(x)
#	define _TARGET(x)
#	define _SSEREGPARM
#endif

/* We don't have any version support information for these */

#if __GNUC__
#	define _ALWAYS_INLINE __attribute__ ((always_inline))
#	define _FLATTEN __attribute__ ((flatten))
#else
#	define _ALWAYS_INLINE
#	define _FLATTEN
#endif

/****************************************************************************/

#ifdef __GNUC__
#	undef GCC_VERSION
#endif

#endif /* _GCC_ATTRIBUTES_ */
