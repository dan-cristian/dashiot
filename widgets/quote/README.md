##Preview

![](http://www.auronmedia.co.uk/githubcontent/QuoteWidgetScreenshot2.png)

##Description

A simple [Dashing](http://shopify.github.com/dashing) widget to display a random inspirational quote. The widget is set to update every 4 hours, however this is easily configurable in the job file. The data is pulled from the free api provided by [Forismatic.com](http://forismatic.com/en/api/).

##Installation

1. Create new widget folder under Dashing installation named 'quote'
2. Copy 'quote.html', 'quote.scss' and 'quote.coffee' into the newly created 'quote' folder
3. Copy 'quote.rb' file into 'jobs' folder
4. Copy 'quote.png' into 'assets\images' folder

To include the widget in a dashboard, add the following snippet to the dashboard layout:

    <li data-row="1" data-col="1" data-sizex="1" data-sizey="1">
      <div data-id="quote" data-view="Quote"></div>
    </li>