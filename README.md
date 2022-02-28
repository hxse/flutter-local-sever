# flutter_demo

local http server

## Getting Started

http://127.0.0.1:8881/data/config.json
* 一律走post请求,method参数标记方法: read,update,delete
* contentType支持三种模式:'text/plain','application/json','multipart/form-data'
    * 其他的都会忽视,text和json其实一样,form-data是二进制默认只接受一个,多了会覆盖(不是追加)
* 本地文件放在data文件夹下,所以请求应该以/data/...开头
* 项目根目录的config.json是配置文件,不可删除
    * rootPath,字段表示数据缓存文件夹,可以是相对路径,也可以是绝对路径,末尾不用带斜杠,但是windows反斜杠转义符'\'一定要两个才行
    * 如果缺少文件会自动生成默认配置文件,如果格式不对,无法识别,会重置成默认值
* data参数,表示请求文件系统,data,会被配置文件里的值自动替换
* 请求文件不要用斜杠/做结尾,请求文件夹要带/斜杠做结尾
* binary,读写文件是否用二进制,默认false
* get-,可选参数,获取文件信息,可以组合使用,bool类型
    * get-content, 获取文件内容
    * get-size, 获取文件大小
    * get-length, 获取文件内容长度
*  文件夹可选参数,bool
    * recursive,仅在读取文件夹时有用,是否递归目录
    * dir-size,读取文件夹size,返回get-size字段,不会递归计算
    * dir-child,返回子文件和文件夹路径,不会递归计算
    * dir-child-num,返回子文件和文件夹的数量,不会递归计算
* 传文件用form-data放post body里面传
    *  http://127.0.0.1:8881/data/temp/249M.mp4.part_1?method=update&mode-part=True
    *  合并时,part文件会按顺序一个接一个读取,单个part文件会全部读入内存,如果part大小是50M,那50M会被全部读入内存,所以文件切割的大小要考虑服务器所能承受内存
    * 默认模式,url路径代表文件位置,form-data字段名被忽略,只识别第一个文件,多个文件按顺序覆盖,所以建议每次只发送一个文件,发送多个用,field-name模式
        *  form-data-multiple=True时,url路径代表文件夹位置,form-data字段名代表文件名(这个未实现,很麻烦,不搞了,建议每个url只发送一个)
   * 发送合并请求时,url里放合并文件的路径,part路径放json里,因为part文件是不需要检查的,之前上传的时候已经检查过了,但是合并后的文件还是需要路径检查的
    * merge:true,合并
        * 同时传一个app/json,包含参考格式,为什么带/data,首先开头的斜杠会被自动程序过滤,然后data会被替换成配置文件里的值
        * ```
          "{chunkList: [{name: /data/temp/249M.mp4.part_0, size: 104857600}, {name: /data/temp/249M.mp4.part_1, size: 104857600}, {name: /data/temp/249M.mp4.part_2, size: 51872377}]}
          ```
    * merge-clean-part:true,合并后删除part文件
    * merge-clean-dir:true,合并后删除父文件夹

* todo
    * 可以把合并文件也做成异步分段
