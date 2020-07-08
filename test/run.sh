reset && \
sudo luarocks make && \
busted test/parser.test.lua && \
busted test/generator.test.lua && \
busted test/annotator.test.lua