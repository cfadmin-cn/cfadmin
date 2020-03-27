local LOG = require "logging"
local aio = require "aio"
local cf = require "cf"

require "utils"

local function run(func_name, ...)
  local ret, err = aio[func_name](...)
  return ret, err
end

--[[

  众所周知! 线程之间是"并行执行"的. 当mkdir与rmdir运行在不同的协程后, 即使是最简单工作, 我们也不保证哪个协程先运行, 哪个任务先结束.

  如果你需要aio库进行串行化的工作时, 请至少将aio的方法按顺序写在同一个协程当中. 这样至少能将其运行在"逻辑顺序性"的情况下.

  example_1展示就了一个错误使用示例! 它将不同的任务放在不同的协程中并让其乱序执行. 这样将打乱你原本的计划. 因为它可能正确(也可能不正确).

  软件设计其中一项重点就是对软件设计质量的把控! 当程序运行在没有人知道会发生什么的情况下(包括作者本人), 那么这就是错误的问题思考方式.

]]



-- -- example_1
-- for i = 1, 100 do

--   cf.fork(function ( ... )
--     LOG:DEBUG("开始删除: logs/" .. i)
--     print(run("rmdir", "logs/" .. i))
--     LOG:DEBUG("结束删除: logs/" .. i)
--   end)

--   cf.fork(function ( ... )
--     LOG:DEBUG("开始创建: logs/" .. i)
--     print(run("mkdir", "logs/" .. i))
--     LOG:DEBUG("结束创建")
--   end)

-- end


--[[

  如果您已经看到这里! 说明已经接受上述建议开始尝试编写"正确"的代码! 那么如何编写逻辑正确的异步IO呢? 下面有些建议供大家参考.

  example_2示例描述了正确的使用方法, 同时也是最可能大家使用到的代码. 它绝大部分场景应该都能工作的很好, 并且不会因为文件IO导致阻塞.

  我们可以看到, 当example_2运行在相同的协程的时候. 他们可以工作的非常好. 因为aio底层已经将异步回调代码修改为同步非阻塞(至少看起来是这样).

  这样的编码可以让底层处于串行化工作领域范围内:"即创建完毕之后才会执行删除操作", 既保留了异步IO的能力, 也保证了逻辑正确性.

]]


-- -- example_2
-- for i = 1, 100 do
--   LOG:DEBUG("开始创建: logs/" .. i)
--   print(run("mkdir", "logs/" .. i))
--   LOG:DEBUG("结束创建")
--   LOG:DEBUG("开始删除: logs/" .. i)
--   print(run("rmdir", "logs/" .. i))
--   LOG:DEBUG("结束删除: logs/" .. i)
-- end


--[[

  example_3在批量任务中派上了用场了!  协程与异步IO的并发使用场景就是:"让多个无相关性的任务提交, 然后统一等待任务完成的那个时刻到来."

  这在执行批量任务的时候优势极其明显. 即使其实际运行结果中并不是按照1->2->3 ... ->100的顺序执行, 但是我们的目的是一致的.

  因为当过程不重要的时候, 只需要保证结果的正确性即可. 就类似编译器指令重排, 虽然顺序不一致但是结果是一致的.

  注意: example_3实现的代码一样与其他两种的场景意义不一样.

]]


-- local index = 1
-- for i = 1, 100 do
--   cf.fork(function ( ... )
--     run("mkdir", "logs/" .. i)
--     index = index + 1 
--     if index == 100 then
--       print("所有文件夹创建完成.")
--     end
--   end)
-- end

-- cf.sleep(3)

-- local index = 1
-- for i = 1, 100 do
--   cf.fork(function ( ... )
--     run("rmdir", "logs/" .. i)
--     index = index + 1 
--     if index == 100 then
--       print("所有文件夹删除完成.")
--     end
--   end)
-- end

--[[

  所以如果您需要外部使用, 请知悉这些内容. 这能让您明白是否真正的需要用到它. 由aio.open创建(一般情况下不可能失败)的对象并不是io库的file对象(元表是__AIO__).

  __AIO__相关方法的行为根据pread/pwrite行为而定, 且read_seek方法并不是真正调用的底层函数. 根据不同平台实现可能也并不是线程安全的, 而且__AIO__会在必要的时候做重入检查(抛出异常).

  同时需要知道__AIO__的读取与写入性能并不会比原生io库高. 所以性能并不是__AIO__对象的优势, 它们的优势在于不会因为同步文件I/O操作长时间阻塞内置事件循环.

  最后, 它与io库的file对象一样需要显示关闭文件描述符(fd). 虽然__AIO__对象在触发gc的时候可以检查并且关闭可能造成的泄露, 但是请不要过于依赖它(因为open files too many错误可能会比gc先到来).

]]
local function test_aio_file_operations()

  local f = assert(aio.open("message.txt"))

  print("写入字节: [hello world!], 长度为: " .. f:write("hello world!"))

  print("读取1个字节为  : " .. f:read(1))

  print("读取2个字节为  : " .. f:read(2))

  print("读取剩余内容为 : " .. f:readall())

  print("重置读取起始位置(offset)", f:read_lseek(0))

  print("读取剩余内容为 : " .. f:readall())

  print("清空文件: ", f:clean() and "成功")

  print("关闭文件: ", f:close() and "成功")

  print("删除message.txt文件: " , assert(aio.remove("message.txt")) and "成功")

end

-- aio.create方法在文件存在的时候会因为创建文件失败而返回nil与错误信息
-- aio.remove方法在文件不存在的时候会因为删除失败而返回nil与错误信息
local function test_aio_create_file_and_delete()

  print("创建message文件: ", assert(aio.create("message")) and "成功")

  print("删除message文件或文件夹: " , assert(aio.remove("message")) and "成功")

end

-- aio.mkdir与aio.rmdir方法用于创建于删除文件夹(aio.remove也可完成删除文件夹)
local function test_aio_create_dir_and_delete()
  print("创建message文件夹: ", assert(aio.mkdir("message")) and "成功")

  print("删除message文件或文件夹: " , assert(aio.rmdir("message")) and "成功")
end

-- aio.truncate方法会截断文件内容, 当它的第二个参数为0/nil/不传递第二个参数的时候您就如同做了清空文件的操作(效果等同于调用f:clean())
-- 这在某些情况下是非常危险的操作, 因为这会立即影响到文件内容. 所以除非您知道自己在做什么, 否则请谨慎使用此方法. 一般情况下不会用到它.
local function test_aio_truncate_file()
  -- aio.truncate("filename", "filesize")
end

-- aio.currentdir方法会返回表示当前路径的字符串
local function test_aio_display_current_dir()
  print("当前目录为: " .. (aio.currentdir() or ""))
end

-- aio.dir方法返回指定目录下的所有文件/文件夹名称(数组)
local function test_aio_display_dir()
  var_dump(aio.dir("."))
end

-- aio.stat / aio.attributes 方法返回指定名称的文件/文件夹的属性
local function test_aio_stat()
  var_dump(aio.stat("."))
  -- var_dump(aio.attributes("."))
end

-- aio.rename 方法将会将会对指定的文件/文件夹重命名, 例如将3rd命名为4rd后, 最后再将其改回3rd
local function test_aio_rename()
  print("将3rd文件夹改为4rd: ", assert(aio.rename("3rd", "4rd")) and "成功")
  print("将4rd文件夹改为3rd: ", assert(aio.rename("4rd", "3rd")) and "成功")
end

-- aio.fflush 方法将会刷新io.file对象的缓冲区(前提是您设置了), 这是一个同步非阻塞的操作. 
-- 真正的刷新操作将会在其它系统线程内执行, 所以您并不用担心主线程会被影响到. 但一般情况下您并不会用用到它
local function test_aio_fflush( ... )
  local f = assert(io.open("test.txt", "a"))
  -- 设置完全缓冲区, 这在缓冲区未被写满或者f:close之前是不会刷写到磁盘上的.
  f:setvbuf("full", "1024")
  f:write("hello world!")
  -- 如果您将以此之后的代码删除或者注释, 您会发现test.txt内并无任何内容.
  -- 但如果您未注释下面的代码, test.txt会正常写入到磁盘上.
  aio.fflush(f)
  f:close()
  -- 如果您不注释下面的这段代码! 文件操作完毕将会被删除, 您将不会知晓任何操作细节.
  aio.remove("test.txt")
end

-- test_aio_create_file_and_delete()

-- test_aio_create_dir_and_delete()

-- test_aio_file_operations()

-- test_aio_display_current_dir()

-- test_aio_display_dir()

-- test_aio_stat()

-- test_aio_rename()

-- test_aio_fflush()



cf.wait()