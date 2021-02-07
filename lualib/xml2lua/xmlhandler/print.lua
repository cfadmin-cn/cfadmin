---@module Handler to generate a simple event trace which 
--outputs messages to the terminal during the XML
--parsing, usually for debugging purposes.
--
--  License:
--  ========
--
--      This code is freely distributable under the terms of the [MIT license](LICENSE).
--
--@author Paul Chakravarti (paulc@passtheaardvark.com)
--@author Manoel Campos da Silva Filho
local print = {}

---Parses a start tag.
-- @param tag table @a {name, attrs} table
-- where name is the name of the tag and attrs 
-- is a table containing the atributtes of the tag
function print:starttag(tag)
    io.write("Start    : "..tag.name.."\n")
    if tag.attrs then
        for k,v in pairs(tag.attrs) do
            io.write(string.format(" + %s='%s'\n", k, v))
        end
    end
end

---Parses an end tag.
-- @param tag table @a {name, attrs} table
-- where name is the name of the tag and attrs 
-- is a table containing the atributtes of the tag
function print:endtag(tag) 
    io.write("End      : "..tag.name.."\n")
end

---Parses a tag content.
-- @param text string @text to process
function print:text(text)
    io.write("Text     : "..text.."\n")
end

---Parses CDATA tag content.
-- @param text string @CDATA content to be processed
function print:cdata(text)
    io.write("CDATA    : "..text.."\n")
end

---Parses a comment tag.
-- @param text string @comment text
function print:comment(text)
    io.write("Comment  : "..text.."\n")
end

---Parses a DTD tag.
-- @param tag table @a {name, attrs} table
-- where name is the name of the tag and attrs 
-- is a table containing the atributtes of the tag
function print:dtd(tag)
    io.write("DTD      : "..tag.name.."\n")
    if tag.attrs then
        for k,v in pairs(tag.attrs) do
            io.write(string.format(" + %s='%s'\n", k, v))
        end 
    end
end

--- Parse a XML processing instructions (PI) tag.
-- @param tag table @a {name, attrs} table
-- where name is the name of the tag and attrs 
-- is a table containing the atributtes of the tag
function print:pi(tag)
    io.write("PI       : "..tag.name.."\n")
    if tag.attrs then
        for k,v in pairs(tag.attrs) do
            io. write(string.format(" + %s='%s'\n",k,v))
        end 
    end
end

---Parse the XML declaration line (the line that indicates the XML version).
-- @param tag table @a {name, attrs} table
-- where name is the name of the tag and attrs 
-- is a table containing the atributtes of the tag
function print:decl(tag)
    io.write("XML Decl : "..tag.name.."\n")
    if tag.attrs then
        for k,v in pairs(tag.attrs) do
            io.write(string.format(" + %s='%s'\n", k, v))
        end
    end
end

return print