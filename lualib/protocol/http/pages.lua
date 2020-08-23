local pages = {}

pages[400] = [[
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
  <html xmlns="http://www.w3.org/1999/xhtml">
  <head>
  	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  	<title>400 Bad Request</title>
  	<style>
  	body {
  	  background-color: #ECECEC;
  	  font-family: 'Open Sans', sans-serif;
  	  font-size: 14px;
  	  color: #3c3c3c;
  	}
  	.error-page {
  		width:600px;
  		margin:0 auto;
  	}
  	.error-page p:first-child {
  	  text-align: center;
  	  font-size: 150px;
  	  font-weight: bold;
  	  line-height: 100px;
  	  letter-spacing: 5px;
  	  color: #fff;
  	}
  	.error-page p:first-child span {
  	  cursor: pointer;
  	  text-shadow: 0px 0px 2px #686868,
  	    0px 1px 1px #ddd,
  	    0px 2px 1px #d6d6d6,
  	    0px 3px 1px #ccc,
  	    0px 4px 1px #c5c5c5,
  	    0px 5px 1px #c1c1c1,
  	    0px 6px 1px #bbb,
  	    0px 7px 1px #777,
  	    0px 8px 3px rgba(100, 100, 100, 0.4),
  	    0px 9px 5px rgba(100, 100, 100, 0.1),
  	    0px 10px 7px rgba(100, 100, 100, 0.15),
  	    0px 11px 9px rgba(100, 100, 100, 0.2),
  	    0px 12px 11px rgba(100, 100, 100, 0.25),
  	    0px 13px 15px rgba(100, 100, 100, 0.3);
  	  -webkit-transition: all .1s linear;
  	  transition: all .1s linear;
  	}
  	.error-page p:first-child span:hover {
  	  text-shadow: 0px 0px 2px #686868,
  	    0px 1px 1px #fff,
  	    0px 2px 1px #fff,
  	    0px 3px 1px #fff,
  	    0px 4px 1px #fff,
  	    0px 5px 1px #fff,
  	    0px 6px 1px #fff,
  	    0px 7px 1px #777,
  	    0px 8px 3px #fff,
  	    0px 9px 5px #fff,
  	    0px 10px 7px #fff,
  	    0px 11px 9px #fff,
  	    0px 12px 11px #fff,
  	    0px 13px 15px #fff;
  	  -webkit-transition: all .1s linear;
  	  transition: all .1s linear;
  	}
  	.error-page p:not(:first-child) {
  	  text-align: center;
  	  color: #666;
  	  font-family: cursive;
  	  font-size: 20px;
  	  text-shadow: 0 1px 0 #fff;
  	  letter-spacing: 1px;
  	  line-height: 2em;
  	  margin-top: -50px;
  	}
  	</style>
  </head>
  <body>
  	<div class="error-page">
  		<p>
  			<span>4</span>
  			<span>0</span>
  			<span>0</span>
  		</p>
  		<p>Bad Request</p>
  	</div>
  </body>
  </html>
]]

pages[401] = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>401 Unauthorized</title>
  <style>
  body {
    background-color: #ECECEC;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    color: #3c3c3c;
  }
  .error-page {
    width:600px;
    margin:0 auto;
  }
  .error-page p:first-child {
    text-align: center;
    font-size: 150px;
    font-weight: bold;
    line-height: 100px;
    letter-spacing: 5px;
    color: #fff;
  }
  .error-page p:first-child span {
    cursor: pointer;
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #ddd,
      0px 2px 1px #d6d6d6,
      0px 3px 1px #ccc,
      0px 4px 1px #c5c5c5,
      0px 5px 1px #c1c1c1,
      0px 6px 1px #bbb,
      0px 7px 1px #777,
      0px 8px 3px rgba(100, 100, 100, 0.4),
      0px 9px 5px rgba(100, 100, 100, 0.1),
      0px 10px 7px rgba(100, 100, 100, 0.15),
      0px 11px 9px rgba(100, 100, 100, 0.2),
      0px 12px 11px rgba(100, 100, 100, 0.25),
      0px 13px 15px rgba(100, 100, 100, 0.3);
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:first-child span:hover {
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #fff,
      0px 2px 1px #fff,
      0px 3px 1px #fff,
      0px 4px 1px #fff,
      0px 5px 1px #fff,
      0px 6px 1px #fff,
      0px 7px 1px #777,
      0px 8px 3px #fff,
      0px 9px 5px #fff,
      0px 10px 7px #fff,
      0px 11px 9px #fff,
      0px 12px 11px #fff,
      0px 13px 15px #fff;
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:not(:first-child) {
    text-align: center;
    color: #666;
    font-family: cursive;
    font-size: 20px;
    text-shadow: 0 1px 0 #fff;
    letter-spacing: 1px;
    line-height: 2em;
    margin-top: -50px;
  }
  </style>
</head>
<body>
  <div class="error-page">
    <p>
      <span>4</span>
      <span>0</span>
      <span>1</span>
    </p>
    <p>Unauthorized</p>
  </div>
</body>
</html>
]]

pages[403] = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>403 Forbidden</title>
  <style>
  body {
    background-color: #ECECEC;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    color: #3c3c3c;
  }
  .error-page {
    width:600px;
    margin:0 auto;
  }
  .error-page p:first-child {
    text-align: center;
    font-size: 150px;
    font-weight: bold;
    line-height: 100px;
    letter-spacing: 5px;
    color: #fff;
  }
  .error-page p:first-child span {
    cursor: pointer;
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #ddd,
      0px 2px 1px #d6d6d6,
      0px 3px 1px #ccc,
      0px 4px 1px #c5c5c5,
      0px 5px 1px #c1c1c1,
      0px 6px 1px #bbb,
      0px 7px 1px #777,
      0px 8px 3px rgba(100, 100, 100, 0.4),
      0px 9px 5px rgba(100, 100, 100, 0.1),
      0px 10px 7px rgba(100, 100, 100, 0.15),
      0px 11px 9px rgba(100, 100, 100, 0.2),
      0px 12px 11px rgba(100, 100, 100, 0.25),
      0px 13px 15px rgba(100, 100, 100, 0.3);
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:first-child span:hover {
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #fff,
      0px 2px 1px #fff,
      0px 3px 1px #fff,
      0px 4px 1px #fff,
      0px 5px 1px #fff,
      0px 6px 1px #fff,
      0px 7px 1px #777,
      0px 8px 3px #fff,
      0px 9px 5px #fff,
      0px 10px 7px #fff,
      0px 11px 9px #fff,
      0px 12px 11px #fff,
      0px 13px 15px #fff;
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:not(:first-child) {
    text-align: center;
    color: #666;
    font-family: cursive;
    font-size: 20px;
    text-shadow: 0 1px 0 #fff;
    letter-spacing: 1px;
    line-height: 2em;
    margin-top: -50px;
  }
  </style>
</head>
<body>
  <div class="error-page">
    <p>
      <span>4</span>
      <span>0</span>
      <span>3</span>
    </p>
    <p>Forbidden</p>
  </div>
</body>
</html>
]]

pages[404] = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>404 Page Not Found</title>
  <style>
  body {
    background-color: #ECECEC;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    color: #3c3c3c;
  }
  .error-page {
    width:600px;
    margin:0 auto;
  }
  .error-page p:first-child {
    text-align: center;
    font-size: 150px;
    font-weight: bold;
    line-height: 100px;
    letter-spacing: 5px;
    color: #fff;
  }
  .error-page p:first-child span {
    cursor: pointer;
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #ddd,
      0px 2px 1px #d6d6d6,
      0px 3px 1px #ccc,
      0px 4px 1px #c5c5c5,
      0px 5px 1px #c1c1c1,
      0px 6px 1px #bbb,
      0px 7px 1px #777,
      0px 8px 3px rgba(100, 100, 100, 0.4),
      0px 9px 5px rgba(100, 100, 100, 0.1),
      0px 10px 7px rgba(100, 100, 100, 0.15),
      0px 11px 9px rgba(100, 100, 100, 0.2),
      0px 12px 11px rgba(100, 100, 100, 0.25),
      0px 13px 15px rgba(100, 100, 100, 0.3);
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:first-child span:hover {
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #fff,
      0px 2px 1px #fff,
      0px 3px 1px #fff,
      0px 4px 1px #fff,
      0px 5px 1px #fff,
      0px 6px 1px #fff,
      0px 7px 1px #777,
      0px 8px 3px #fff,
      0px 9px 5px #fff,
      0px 10px 7px #fff,
      0px 11px 9px #fff,
      0px 12px 11px #fff,
      0px 13px 15px #fff;
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:not(:first-child) {
    text-align: center;
    color: #666;
    font-family: cursive;
    font-size: 20px;
    text-shadow: 0 1px 0 #fff;
    letter-spacing: 1px;
    line-height: 2em;
    margin-top: -50px;
  }
  </style>
</head>
<body>
  <div class="error-page">
    <p>
      <span>4</span>
      <span>0</span>
      <span>4</span>
    </p>
    <p>Page Not Found</p>
  </div>
</body>
</html>
]]

pages[413] = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>413 Payload Too Large</title>
  <style>
  body {
    background-color: #ECECEC;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    color: #3c3c3c;
  }
  .error-page {
    width:600px;
    margin:0 auto;
  }
  .error-page p:first-child {
    text-align: center;
    font-size: 150px;
    font-weight: bold;
    line-height: 100px;
    letter-spacing: 5px;
    color: #fff;
  }
  .error-page p:first-child span {
    cursor: pointer;
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #ddd,
      0px 2px 1px #d6d6d6,
      0px 3px 1px #ccc,
      0px 4px 1px #c5c5c5,
      0px 5px 1px #c1c1c1,
      0px 6px 1px #bbb,
      0px 7px 1px #777,
      0px 8px 3px rgba(100, 100, 100, 0.4),
      0px 9px 5px rgba(100, 100, 100, 0.1),
      0px 10px 7px rgba(100, 100, 100, 0.15),
      0px 11px 9px rgba(100, 100, 100, 0.2),
      0px 12px 11px rgba(100, 100, 100, 0.25),
      0px 13px 15px rgba(100, 100, 100, 0.3);
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:first-child span:hover {
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #fff,
      0px 2px 1px #fff,
      0px 3px 1px #fff,
      0px 4px 1px #fff,
      0px 5px 1px #fff,
      0px 6px 1px #fff,
      0px 7px 1px #777,
      0px 8px 3px #fff,
      0px 9px 5px #fff,
      0px 10px 7px #fff,
      0px 11px 9px #fff,
      0px 12px 11px #fff,
      0px 13px 15px #fff;
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:not(:first-child) {
    text-align: center;
    color: #666;
    font-family: cursive;
    font-size: 20px;
    text-shadow: 0 1px 0 #fff;
    letter-spacing: 1px;
    line-height: 2em;
    margin-top: -50px;
  }
  </style>
</head>
<body>
  <div class="error-page">
    <p>
      <span>4</span>
      <span>1</span>
      <span>3</span>
    </p>
    <p>Payload Too Large</p>
  </div>
</body>
</html>
]]

pages[431] = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>431 Request Header Fields Too Large</title>
  <style>
  body {
    background-color: #ECECEC;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    color: #3c3c3c;
  }
  .error-page {
    width:600px;
    margin:0 auto;
  }
  .error-page p:first-child {
    text-align: center;
    font-size: 150px;
    font-weight: bold;
    line-height: 100px;
    letter-spacing: 5px;
    color: #fff;
  }
  .error-page p:first-child span {
    cursor: pointer;
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #ddd,
      0px 2px 1px #d6d6d6,
      0px 3px 1px #ccc,
      0px 4px 1px #c5c5c5,
      0px 5px 1px #c1c1c1,
      0px 6px 1px #bbb,
      0px 7px 1px #777,
      0px 8px 3px rgba(100, 100, 100, 0.4),
      0px 9px 5px rgba(100, 100, 100, 0.1),
      0px 10px 7px rgba(100, 100, 100, 0.15),
      0px 11px 9px rgba(100, 100, 100, 0.2),
      0px 12px 11px rgba(100, 100, 100, 0.25),
      0px 13px 15px rgba(100, 100, 100, 0.3);
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:first-child span:hover {
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #fff,
      0px 2px 1px #fff,
      0px 3px 1px #fff,
      0px 4px 1px #fff,
      0px 5px 1px #fff,
      0px 6px 1px #fff,
      0px 7px 1px #777,
      0px 8px 3px #fff,
      0px 9px 5px #fff,
      0px 10px 7px #fff,
      0px 11px 9px #fff,
      0px 12px 11px #fff,
      0px 13px 15px #fff;
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:not(:first-child) {
    text-align: center;
    color: #666;
    font-family: cursive;
    font-size: 20px;
    text-shadow: 0 1px 0 #fff;
    letter-spacing: 1px;
    line-height: 2em;
    margin-top: -50px;
  }
  </style>
</head>
<body>
  <div class="error-page">
    <p>
      <span>4</span>
      <span>3</span>
      <span>1</span>
    </p>
    <p>Request Header Fields Too Large</p>
  </div>
</body>
</html>
]]

pages[500] = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>500 Internal Server Error</title>
  <style>
  body {
    background-color: #ECECEC;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    color: #3c3c3c;
  }
  .error-page {
    width:600px;
    margin:0 auto;
  }
  .error-page p:first-child {
    text-align: center;
    font-size: 150px;
    font-weight: bold;
    line-height: 100px;
    letter-spacing: 5px;
    color: #fff;
  }
  .error-page p:first-child span {
    cursor: pointer;
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #ddd,
      0px 2px 1px #d6d6d6,
      0px 3px 1px #ccc,
      0px 4px 1px #c5c5c5,
      0px 5px 1px #c1c1c1,
      0px 6px 1px #bbb,
      0px 7px 1px #777,
      0px 8px 3px rgba(100, 100, 100, 0.4),
      0px 9px 5px rgba(100, 100, 100, 0.1),
      0px 10px 7px rgba(100, 100, 100, 0.15),
      0px 11px 9px rgba(100, 100, 100, 0.2),
      0px 12px 11px rgba(100, 100, 100, 0.25),
      0px 13px 15px rgba(100, 100, 100, 0.3);
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:first-child span:hover {
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #fff,
      0px 2px 1px #fff,
      0px 3px 1px #fff,
      0px 4px 1px #fff,
      0px 5px 1px #fff,
      0px 6px 1px #fff,
      0px 7px 1px #777,
      0px 8px 3px #fff,
      0px 9px 5px #fff,
      0px 10px 7px #fff,
      0px 11px 9px #fff,
      0px 12px 11px #fff,
      0px 13px 15px #fff;
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:not(:first-child) {
    text-align: center;
    color: #666;
    font-family: cursive;
    font-size: 20px;
    text-shadow: 0 1px 0 #fff;
    letter-spacing: 1px;
    line-height: 2em;
    margin-top: -50px;
  }
  </style>
</head>
<body>
  <div class="error-page">
    <p>
      <span>5</span>
      <span>0</span>
      <span>0</span>
    </p>
    <p>Internal Server Error</p>
  </div>
</body>
</html>
]]

pages[501] = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>501 Not Implemented</title>
  <style>
  body {
    background-color: #ECECEC;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    color: #3c3c3c;
  }
  .error-page {
    width:600px;
    margin:0 auto;
  }
  .error-page p:first-child {
    text-align: center;
    font-size: 150px;
    font-weight: bold;
    line-height: 100px;
    letter-spacing: 5px;
    color: #fff;
  }
  .error-page p:first-child span {
    cursor: pointer;
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #ddd,
      0px 2px 1px #d6d6d6,
      0px 3px 1px #ccc,
      0px 4px 1px #c5c5c5,
      0px 5px 1px #c1c1c1,
      0px 6px 1px #bbb,
      0px 7px 1px #777,
      0px 8px 3px rgba(100, 100, 100, 0.4),
      0px 9px 5px rgba(100, 100, 100, 0.1),
      0px 10px 7px rgba(100, 100, 100, 0.15),
      0px 11px 9px rgba(100, 100, 100, 0.2),
      0px 12px 11px rgba(100, 100, 100, 0.25),
      0px 13px 15px rgba(100, 100, 100, 0.3);
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:first-child span:hover {
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #fff,
      0px 2px 1px #fff,
      0px 3px 1px #fff,
      0px 4px 1px #fff,
      0px 5px 1px #fff,
      0px 6px 1px #fff,
      0px 7px 1px #777,
      0px 8px 3px #fff,
      0px 9px 5px #fff,
      0px 10px 7px #fff,
      0px 11px 9px #fff,
      0px 12px 11px #fff,
      0px 13px 15px #fff;
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:not(:first-child) {
    text-align: center;
    color: #666;
    font-family: cursive;
    font-size: 20px;
    text-shadow: 0 1px 0 #fff;
    letter-spacing: 1px;
    line-height: 2em;
    margin-top: -50px;
  }
  </style>
</head>
<body>
  <div class="error-page">
    <p>
      <span>5</span>
      <span>0</span>
      <span>1</span>
    </p>
    <p>Not Implemented</p>
  </div>
</body>
</html>
]]

pages[505] = [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>505 HTTP Version Not Supported</title>
  <style>
  body {
    background-color: #ECECEC;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    color: #3c3c3c;
  }
  .error-page {
    width:600px;
    margin:0 auto;
  }
  .error-page p:first-child {
    text-align: center;
    font-size: 150px;
    font-weight: bold;
    line-height: 100px;
    letter-spacing: 5px;
    color: #fff;
  }
  .error-page p:first-child span {
    cursor: pointer;
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #ddd,
      0px 2px 1px #d6d6d6,
      0px 3px 1px #ccc,
      0px 4px 1px #c5c5c5,
      0px 5px 1px #c1c1c1,
      0px 6px 1px #bbb,
      0px 7px 1px #777,
      0px 8px 3px rgba(100, 100, 100, 0.4),
      0px 9px 5px rgba(100, 100, 100, 0.1),
      0px 10px 7px rgba(100, 100, 100, 0.15),
      0px 11px 9px rgba(100, 100, 100, 0.2),
      0px 12px 11px rgba(100, 100, 100, 0.25),
      0px 13px 15px rgba(100, 100, 100, 0.3);
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:first-child span:hover {
    text-shadow: 0px 0px 2px #686868,
      0px 1px 1px #fff,
      0px 2px 1px #fff,
      0px 3px 1px #fff,
      0px 4px 1px #fff,
      0px 5px 1px #fff,
      0px 6px 1px #fff,
      0px 7px 1px #777,
      0px 8px 3px #fff,
      0px 9px 5px #fff,
      0px 10px 7px #fff,
      0px 11px 9px #fff,
      0px 12px 11px #fff,
      0px 13px 15px #fff;
    -webkit-transition: all .1s linear;
    transition: all .1s linear;
  }
  .error-page p:not(:first-child) {
    text-align: center;
    color: #666;
    font-family: cursive;
    font-size: 20px;
    text-shadow: 0 1px 0 #fff;
    letter-spacing: 1px;
    line-height: 2em;
    margin-top: -50px;
  }
  </style>
</head>
<body>
  <div class="error-page">
    <p>
      <span>5</span>
      <span>0</span>
      <span>5</span>
    </p>
    <p>HTTP Version Not Supported</p>
  </div>
</body>
</html>
]]



return pages
