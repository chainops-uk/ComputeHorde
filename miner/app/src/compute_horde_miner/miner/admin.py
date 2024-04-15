from django.contrib import admin  # noqa
from django.contrib.admin import register  # noqa

from compute_horde_miner.miner.models import AcceptedJob, Validator, ValidatorBlacklist

admin.site.site_header = "compute_horde_miner Administration"
admin.site.site_title = "compute_horde_miner"
admin.site.index_title = "Welcome to compute_horde_miner Administration"

class ReadOnlyAdmin(admin.ModelAdmin):
    change_form_template = "admin/read_only_view.html"

    def has_add_permission(self, *args, **kwargs):
        return False

    def has_change_permission(self, *args, **kwargs):
        return False

    def has_delete_permission(self, *args, **kwargs):
        return False

admin.site.register(AcceptedJob, admin_class=ReadOnlyAdmin)
admin.site.register(Validator, admin_class=ReadOnlyAdmin)
admin.site.register(ValidatorBlacklist)
