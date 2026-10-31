$(function () {
  $('img').each(function () {
    if ($(this).prop('naturalWidth') == 1 && $(this).prop('naturalHeight') == 1) { $(this).hide() }
  })

  $(document).on('click', 'a[data-confirm]', function (e) {
    const message = $(this).data('confirm')
    if (!confirm(message)) {
      e.preventDefault()
      e.stopped = true
    }
  })

  function ajaxCompleted () {
    $('[data-bs-toggle="tooltip"]').tooltip({
      html: true
    })

    // Shades each score's cell from white (0) to green (100)
    $('.score').each(function () {
      const t = Math.min(Math.max(parseFloat($(this).text()) / 100, 0), 1) || 0
      const [r, g, b] = [[255, 0x2D], [255, 0xB9], [255, 0x63]].map(([from, to]) => Math.round(from + (to - from) * t))
      $(this).closest('td').css('background-color', `rgb(${r}, ${g}, ${b})`).addClass('text-dark')
    })
  }
  $(document).ajaxComplete(function () {
    ajaxCompleted()
  })
  ajaxCompleted()

  var $sg = $('#substack-notes-gallery')
  if ($sg.length) {
    $(window).on('load', function () {
      $sg.masonry({ itemSelector: '.grid-item', columnWidth: '.grid-sizer', percentPosition: true })
      $sg.animate({ opacity: 1 })
    })
  }
})
