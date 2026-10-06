title

## About

Like many on HN I was worried about AI slop masquerading as human, and wondered if some users were using LLMs in their comments. Its a kind of pattern recognition for me, I can smell when something seems off and LLM text does seem similar in many ways. 

I wanted to look at two things, did a user change their writing style and could this new style be identified as LLM text. This project can only really answer the first facet. The assumption is that if a user changed after the date of mass LLM adoption it might be possible that the change was due to them using LLM generated text. 

This project shows how a user has changed their style over time, and shows the top 100 of users who may have changed the most after 2023.  It uses the Clickhouse Playground to query Hacker News comments. 

Note that users are not allowed to use LLM generated text by the Hacker News rules. See more about this and other considerations later on.

This project was inspired by this post https://news.ycombinator.com/item?id=43705632 and by the comment underneath, by zX41ZdbW  https://news.ycombinator.com/item?id=43734314
The dataset, added by zX41ZdbW "hackernews_history" is used. 

Free users of the playground cannot create tables, so we have to change the example query to use sub queries but substantially it's similar. 

The project was also inspired by https://news.ycombinator.com/item?id=46829029 which finally encouraged me to try this and put it behind a little web page.  

The hackernews_history table may contain multiple versions of a comment. A comment may have been flag killed or deleted or otherwise edited. So there's some deduplication so that only one comment text per comment row is recorded. There is a `hackernews` table on clickhouse playground without the history but this hasn't been updated since 2023.

The method is a simple hashed-word cosine similarity. Words within a comment are split, hashed and put into one of 512 bins. 

Only users with comments before Jan 2023 (mass adoption of LLMs) are counted.

Users must be somewhat active users. 

It counts how many words users make in a 6 month blocks. Users must have at least three 6 month blocks before and after 2023 where they have written more than 500 words. 

There are two queries: for a specific user, and for a batch of users. There is a python script that performs batches and then merges together the results, giving a final top_100.csv file of the users most likely to have changed style from before and after 2023. 

For a specific user, a cumulative score of before 2023 is calculated and the output shows each active 6 month block before and after and gives similarity to that.

The thumbnail / stylometric method used here is simple. Better methods could and should be used. 

For example, Burrows Delta calculates a reference text distribution. For example from all comments from all users and that method would be good to see which users are most similar to other users. Ideally we want to determine two things, did the user change their writing and is the new writing identified as LLM text, so any similarity method can only really help with the former. 

## Results

CAVEAT: This data is almost probably wrong and should not imply anything about the users in general or any specific user. 
CAVEAT: People should adapt and investigate themselves if they want to take this further. 

Overall, it looks like most active old users are not using LLMs.

From the top 100 users, the range was 88 out of 100 to, at the top, 54 out of 100. The general picture with some closer examination of these accounts is that they do not seem to show LLM usage, but more like a change in how they comment and use the site (see below)


## Discussion

There was more variation when the number of words (tokens) in a time period was reduced, and this also lead to more "active" periods. These additional time periods had less activity and so the words written in these times would carry more weight. I decided 500 words in 6 months was a good compromise, but it might be smoothing over actual differences. 

Probably more change will be calculated if there are less sample buckets - if the user signed up in 2022 and only posted a few times before and since, for example. Maybe instead of 6 months periods, we could look at 1 year. 

The limit of 500 words per 6 months may filter out some LLM usage or small amount of text in many comments. 
Performance, zX41ZdbW originally used 128 bins which works fine and is quicker and reduces RAM usage but might lead to different words being counted as the same one. 

Note that users are not allowed to use AI generated text in comments, but the no LLM rule was introduced in 2026 (6 months ago https://news.ycombinator.com/item?id=47340079 )

Before that some users may have used it, or may have mixed in with their normal writing from time to time. Determining that might be tricky. 

Logically and generally most older users are not going to be changing their usage of social media substantially.

Baseline calculation. While Jan 2023 was set as the time of mass LLM adoption as this was when the chatGPT was released into the wild (An AI Eternal September), for normal users it's probably only in more recent years 25/26 that more and more people are actually using it for more things.

Change in topics. Since 2023 was a watershed moment, the topics that were discussed on HN also changed.  The vocabulary we use when talking about LLMs have changed the overall vocabulary. It could be that any changes before and after may reflect a change in topics. 

Change in usage: Some types of comments, like the replies under "Ask HN: Who Wants To Be Hired" posts are formatted differently than usual comments and people will use different words. So if a user talked normally before and is now just using it to find jobs, it would probably show this change. I also saw similar things with Show HN's. Users also appear to be posting to hire people where before they may have been commenting normally and vice versa. As users grow into greybeards they may promote their projects or stop doing so.  Additionally many of the top users are changed their usage into being helpful users, showing duplication submissions, links to archives, messages about the guidelines etc. 

## My own LLM usage for this project:

I used gtp-6.1-sol to help write the sql queries and the python batch script, with about 26 requests and 290K tokens spent costing around 40 cents. 

I don't use LLM to write HN comments, and this readme is 100% my own words.


TODO

Webpage.

front + check user

second page, list top 