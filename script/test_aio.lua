local LOG = require "logging"
local aio = require "aio"
local cf = require "cf"

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


cf.wait()