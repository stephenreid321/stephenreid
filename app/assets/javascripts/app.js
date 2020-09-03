$(function() {

  $("#lightgallery").lightGallery({
    showAfterLoad: false,
    thumbnail: true,
    selector: 'a'
  }).css({
    opacity: 0
  });

  $(".blog_post a[href^=http]").attr('target', '_blank')

  $('[data-toggle="tooltip"]').tooltip()

  $("abbr.timeago").timeago()

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
    alert($(this).prev().val())
    $(this).html($(this).prev().val());
  });

});