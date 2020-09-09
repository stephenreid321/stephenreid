$(function() {

  $("#lightgallery").lightGallery({
    showAfterLoad: false,
    thumbnail: true,
    selector: 'a'
  }).css({
    opacity: 0
  });

  $(".blog_post a[href^=http]").attr('target', '_blank')

  $("abbr.timeago").timeago()

  $('[data-toggle="tooltip"]').tooltip()

  $(document).on('click', 'a[data-confirm]', function(e) {
    var message = $(this).data('confirm');
    if (!confirm(message)) {
      e.preventDefault();
      e.stopped = true;
    }
  });

  $(document).on('click', 'a.popup', function(e) {
    window.open(this.href, null, 'scrollbars=yes,width=600,height=600,left=150,top=150').focus();
    return false;
  });

  $('.card').hover(function() {
    $('.showOnHover', this).addClass('d-sm-inline')
  }, function() {
    $('.showOnHover', this).removeClass('d-sm-inline')
  })

  $('.range-slider__range').on('input', function() {
    $(this).next().html($(this).val());
  });

  $('.range-slider__value').each(function() {
    $(this).html($(this).prev().val());
  });

  function ajaxCompleted() {

    $('.rg').each(function() {
      var d = parseFloat($(this).text())
      if (d > 0)
        $(this).css('color', 'green')
      else if (d < 0)
        $(this).css('color', 'red')
    })

  }
  $(document).ajaxComplete(function() {
    ajaxCompleted()
  });
  ajaxCompleted()

});