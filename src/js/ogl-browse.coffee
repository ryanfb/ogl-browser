---
---

repos = []

add_hathitrust_repo = (repo_li_id, identifier, repo_name) ->
  console.log('add hathitrust repo: ' + identifier)
  repo_li = $("##{repo_li_id}")
  loader = ($('<div>').attr('class','ui active mini loader'))
  repo_li.append(loader)
  $.ajax "http://catalog.hathitrust.org/api/volumes/full/htid/#{identifier}.json",
    type: 'GET'
    dataType: 'json'
    crossDomain: 'true'
    error: (jqXHR, textStatus, errorThrown) ->
      console.log('AJAX error')
      console.log(jqXHR)
      console.log(textStatus)
      console.log(errorThrown)
      loader.remove()
    success: (data, textStatus, jqXHR) ->
      # console.log('hathitrust success for ' + identifier)
      # console.log(data)
      # console.log(data.records)
      for record_key,record of data.records
        # console.log(record)
        repo_li.append($('<p>').append($('<a>').attr('href',record.recordURL).attr('target','_blank').text(identifier + ' on HathiTrust')))
        repo_li.append($('<p>').append($('<a>').attr('href','https://ryanfb.github.io/hocr-reader/#/read/OpenGreekAndLatin/' + repo_name).attr('target','_blank').text(identifier + ' in hOCR Reader')))
        xml = $.parseXML(record['marc-xml'])
        # console.log(xml)
        for key in ['245','100','243','260'] # 500 504 700
          record_text = $(xml).find("datafield[tag=#{key}]").children('subfield').text()
          record_text = record_text.replace(/([,/:])([^ ])/g, '\$1 \$2')
          if record_text
            repo_li.append($('<p>').text(record_text))
      htid_item = _.filter(data['items'], (i) -> i['htid'] == identifier)[0]
      enumcron = htid_item['enumcron']
      orig = htid_item['orig']
      if orig
        repo_li.append($('<a>').attr('href',htid_item['itemURL']).text('Original from ' + orig))
      if enumcron
        repo_li.append($('<p>').text(enumcron))
      loader.remove()

add_archive_repo = (repo_li_id, identifier, repo_name) ->
  console.log('add archive repo: ' + identifier)
  # $.ajax "https://archive.org/details/#{identifier}&output=json",
  archive_link = $('<a>').attr('href',"https://archive.org/details/#{identifier}").attr('target','_blank').text(identifier + ' on archive.org')
  repo_li = $("##{repo_li_id}")
  repo_li.append($('<p>').append(archive_link))
  repo_li.append($('<p>').append($('<a>').attr('href','https://ryanfb.github.io/hocr-reader/#/read/OpenGreekAndLatin/' + repo_name).attr('target','_blank').text(identifier + ' in hOCR Reader')))
  loader = ($('<div>').attr('class','ui active mini loader'))
  repo_li.append(loader)
  $.ajax "https://openlibrary.org/ia/#{identifier}.json",
    type: 'GET'
    dataType: 'json'
    crossDomain: 'true'
    error: (jqXHR, textStatus, errorThrown) ->
      console.log('AJAX error')
      loader.remove()
    success: (data, textStatus, jqXHR) ->
      # console.log('archive success for ' + identifier)
      # console.log(data)
      loader.remove()
      for key in ['title','subtitle','by_statement','publish_date','publishers','publish_places']
        if data[key]
          repo_li.append($('<p>').text(data[key]))

build_interface = ->
  repo_list = $('<ul>').attr('id','repo_list').attr('class','list-group')
  $('#content').append(repo_list)
  ocr_pattern = /[._]?201\d+-\d\d-\d\d-\d\d-\d\d[._]?/
  scan_pattern = /_.*$/
  repos = _.sortBy(repos, (repo) -> repo.updated_at).reverse()
  for repo in repos
    repo_url_fragment = _.last(repo.html_url.split('/'))
    if repo_url_fragment.match(ocr_pattern)
      ocr_identifier = repo_url_fragment.replace(ocr_pattern,'').replace(scan_pattern,'')
      if ocr_identifier == 'ddd'
        continue
      repo_link = $('<a>').attr('href',repo.html_url).attr('target','_blank').text(repo_url_fragment)
      repo_li_id = repo_url_fragment.replace(/\./g,'_')
      repo_li = $('<li>').attr('id',repo_li_id).attr('class','list-group-item')
      repo_li.append(repo_link)
      repo_list.append(repo_li)
      if ocr_identifier.match(/\./) # hathitrust
        if ocr_identifier.match(/\.ark-/)
          ocr_identifier = ocr_identifier.replace(/\.ark-/,'.ark:').replace(/-/g,'/')
        else
          ocr_identifier = ocr_identifier.replace(/\.-/,'.$')
        add_hathitrust_repo(repo_li_id, ocr_identifier, repo.name)
      else # archive.org
        add_archive_repo(repo_li_id, ocr_identifier, repo.name)

grab_repo_page = (url, callback) ->
  console.log('grab_repo_page: ' + url)
  $.ajax url,
    type: 'GET'
    dataType: 'json'
    crossDomain: 'true'
    error: (jqXHR, textStatus, errorThrown) ->
      console.log('AJAX error')
    success: (data, textStatus, jqXHR) ->
      console.log(jqXHR.getResponseHeader('Link'))
      links = jqXHR.getResponseHeader('Link').split(',')
      next = (link.split(';')[0] for link in links when link.split(';')[1] is ' rel="next"')
      repos = repos.concat(data)
      if next.length > 0
        grab_repo_page(next[0][1..-2], callback)
      else # last page
        callback()

$(document).ready ->
  console.log('ready')
  grab_repo_page('https://api.github.com/users/OpenGreekAndLatin/repos?per_page=100', build_interface)
