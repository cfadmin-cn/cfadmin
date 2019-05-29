## 用户自定义库目录

  此目录是用户自定义目录, cf开发者不会对3rd内部文件进行任何意义上的修改, 3rd内组织方式需要用户自行确定.

  在使用者编译cf的make build, make rebuild, make clean等命令的时候将会同时传入到3rd的Makefile内.

  3rd也为用户自定义库提供整合方式或联合编译(如有需要), 使用者在开发阶段可能会需要自己编写一套业务维护库.

  3rd的库维护者应该(至少)维护上述三个编译命令并使其正常工作. 同时, 维护者也需要至少保证以下两点:

    1. 3rd库的维护者(至少)需要保证引用名唯一性;

    2. 3rd库的维护者(至少)需要保证无(除cf)的底层特殊依赖性;

  注: 在无需编译的情况下, 使用者可以讲makefile看做一套自定义库代码整理集合. 有助于用户自行组织库目录.

## 如何在3rd维护自己的lua库?

  1. 将文件copy到3rd目录下(这里假设直接copy到3rd根目录, 当然也可以自行构建目录结构)

  2. 在main.lu文件内使用```local lib = require "3rd.you_lib_name"```

  3. 开始使用.

## 如何在3rd维护自己的lua C库?

  1. 按照lua C API开发模式开发完毕(可参考luaclib内的文件).

  2. 将源码copy到3rd目录下, 并在修改```3rd/Makefile```进行进行联合编译.

  3. 编译完成之后, 执行自己定义的脚本整理文件与路径.

  4. 在main.lu文件内使用```local lib = require "3rd.you_lib_name"```

  5. 开始使用.

## 最简单3rd用户库编写实例

  首先, 在3rd目录下新建一个名为```printer.lua```的文件, 其内容如下:

  ```lua
  return function (...)
    return print(...)
  end
  ```

  然后, 清空```script/main.lua```内的所有内容, 然后输入以下内容:

  ```lua
  local printer = require "3rd.printer"

  printer("这是我在3rd内编写的库")
  ```

  最后, 使用```./cfadmin``` 命令运行并查看效果.
