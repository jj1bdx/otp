# NO LONGER VALID: OS X wxgtk build formulas

* This set of patches does not build on Mavericks 10.9 and R16B03.

## For the reference only

* For Mountain Lion 10.8.3

* wxgtk.rb: for wxGTK 2.8
* lib_wx_configure.in.diff: merged patch for lib/wx/configure.in.diff

* See http://23min.com/2013/01/erlang-observer-debugger-on-mountain-lion/ for the further details

## HOWTO

    brew install wxgtk.rb
    env KERL_CONFIGURE_OPTIONS="--enable-darwin-64bit \
                                --disable-hipe \
				--enable-vm-probes \
				--with-dynamic-trace=dtrace \
				--disable-native-libs \
				--disable-hipe \
				--enable-kernel-poll \
				--without-odbc \
				--enable-threads \
				--enable-smp-support \
				--with-wxdir=/usr/local/Cellar/wxgtk/2.8.12 \
				--with-wx-config=/usr/local/Cellar/wxgtk/2.8.12/bin/wx-config" \
    kerl build git https://github.com/jj1bdx/otp kr-r16b-osx-wx kr-r16b-osx-wx

