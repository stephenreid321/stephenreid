$(function () {
  $('img').each(function () {
    if ($(this).prop('naturalWidth') == 1 && $(this).prop('naturalHeight') == 1) { $(this).hide() }
  })

  $('.card.post, .card.software').hover(function () {
    $('.card-text small', this).removeClass('text-muted')
  }, function () {
    $('.card-text small', this).addClass('text-muted')
  })

  $('#lightgallery').lightGallery({
    showAfterLoad: false,
    thumbnail: true,
    selector: 'a'
  }).css({
    opacity: 0
  })

  if ($('.blog_post').length > 0 && $('.blog_post').html().indexOf('h2') > 0) {
    $('#toc').toc({
      container: '.blog_post',
      selectors: 'h1,h2,h3,h4'
    })
  }

  $('.blog_post a[href^=http]').attr('target', '_blank')
  $('.blog_post table').addClass('table')

  $('abbr.timeago').timeago()

  $(document).on('click', 'a[data-confirm]', function (e) {
    const message = $(this).data('confirm')
    if (!confirm(message)) {
      e.preventDefault()
      e.stopped = true
    }
  })

  $(document).on('click', 'a.popup', function (e) {
    window.open(this.href, null, 'scrollbars=yes,width=600,height=600,left=150,top=150').focus()
    return false
  })

  $('.card').hover(function () {
    $('.showOnHover', this).addClass('d-lg-inline')
  }, function () {
    $('.showOnHover', this).removeClass('d-lg-inline')
  })

  $('.block').hover(
    function () {
      $('.block-edit', this).show()
    },
    function () {
      $('.block-edit', this).hide()
    }
  )

  $('.range-slider__range').on('input', function () {
    $(this).next().html($(this).val())
  })

  $('.range-slider__value').each(function () {
    $(this).html($(this).prev().val())
  })

  function ajaxCompleted () {
    $('[data-toggle="tooltip"]').tooltip({
      html: true
    })

    $('.rg').each(function () {
      const d = parseFloat($(this).text())
      const b = 0
      if (d > b) { $(this).css('color', 'green') } else if (d < b) { $(this).css('color', 'red') }
    })

    $('.score').each(function () {
      const d = parseFloat($(this).text())
      const scale = chroma.scale(['white', '#2DB963'])
      $(this).closest('td').css('background-color', scale(d / 100).hex()).addClass('text-dark')
    })
  }
  $(document).ajaxComplete(function () {
    ajaxCompleted()
  })
  ajaxCompleted()
})
