# OS X wxgtk build formulas

* For Mountain Lion 10.8.3

* wxgtk.rb: for wxGTK 2.8
* erlang.rb: for Erlang R15B03-1
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
    kerl build git https://github.com/jj1bdx/otp kr-r15b03-1-osx-wx kr-r15b03-1-osx-wx

