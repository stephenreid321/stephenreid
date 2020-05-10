
$(function () {
  
  $(".blog_post a[href^=http]").attr('target', '_blank')

  $('[data-toggle="tooltip"]').tooltip()

  $("abbr.timeago").timeago()

  $(document).on('click', 'a[data-confirm]', function (e) {
    var message = $(this).data('confirm');
    if (!confirm(message)) {
      e.preventDefault();
      e.stopped = true;
    }
  });

  $(document).on('click', 'a.popup', function (e) {
    window.open(this.href, null, 'scrollbars=yes,width=600,height=600,left=150,top=150').focus();
    return false;
  });

  $('.card').hover(function () {
    $('.showOnHover', this).addClass('d-sm-inline')
  }, function () {
    $('.showOnHover', this).removeClass('d-sm-inline')
  })

});