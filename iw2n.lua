local http = require('socket.http')
local stringx = require('pl.stringx')
local tablex = require('pl.tablex')
local pp = require('pl.pretty')
local dkjson = require('dkjson')

local imdb_id = arg[1]

if not imdb_id then
    print([[
Usage: lua ]] .. arg[0] .. [[ <imdb_user_id>

Dependencies: dkjson and penlight
sudo install luarocks dkjson
sudo install luarocks penlight]])
    os.exit(1)
end

local function nextguide_url(phrase, limit)
    limit = limit or 21
    return 'http://api-guide.nextguide.tv/api/faceted_search.json?inc_images=1&limit=' .. limit .. '&src_ids=n,a,h,i&headend_id=DITV807&phrase=' .. phrase
end

local function escape(str)
    local nstring = str
    nstring = stringx.replace(str, '  ', ' ')
    nstring = stringx.replace(str, '\'', '')
    nstring = stringx.replace(str, ' ', '%20')
    return nstring
end

--------------------------------------------------------------------------------
io.write('Finding'); io.flush()

local imdb = 'http://rss.imdb.com/user/ur' .. imdb_id .. '/watchlist'
io.write('.'); io.flush()
local result = stringx.splitlines(http.request(imdb))
local movies = {}
local movie = {}

for _, line in ipairs(result) do
    line = stringx.strip(line)

    if line == '<item>' then
        if movie.title then
            table.insert(movies, movie)
        end
        movie = {}
    else
        local title, year = string.match(line, '<title>(.+) %((%d+)%)</title>')
        local link = string.match(line, '<link>(.+)</link>')

        if title then
            movie.title = title
            movie.year = year
        elseif link then
            movie.link = link
            movie.uid = string.match(link, 'http://www.imdb.com/title/tt(%d+)/')
        end
    end
end

math.randomseed(os.time())
local mindex = math.random(#movies)

while true do
    io.write('.'); io.flush()
    local url = nextguide_url(escape(movies[mindex].title), 1)
    local nextguide = http.request(url)
    local data = dkjson.decode(nextguide)

    if data and data.movies and data.movies[1] then
        local movie = data.movies[1]
        local id = string.match(movie.netflix_id or '', 'http://api.netflix.com/catalog/titles/movies/(%d+)')
        if id then
            io.write(' ' .. movie.t .. '\n')
            print('')
            print(movie.s)
            print('')
            print('http://www.netflix.com/WiPlayer?movieid=' .. id)
            break
        end
    end
    mindex = (mindex + 1) % #movies
end
