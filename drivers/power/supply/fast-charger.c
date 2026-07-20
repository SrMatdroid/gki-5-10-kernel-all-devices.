// SPDX-License-Identifier: GPL-2.0-only
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/power_supply.h>
#include <linux/device.h>
#include <linux/stat.h>
#include <linux/slab.h>
#include <linux/workqueue.h>
#include <linux/delay.h>
#include <linux/err.h>
#include <linux/mutex.h>

static int enabled = 1;
static int fcc = 8000000;
static int ctl_max = 16;
static int temp_limit = 450;
static int temp_safe = 480;

static struct power_supply *bat;
static struct delayed_work init_wq;
static struct delayed_work mon_wq;
static bool ready;
static bool stopped;
static DEFINE_MUTEX(lock);

static int set_limits(int ua, int ctl)
{
	union power_supply_propval v;
	int ret;

	if (!bat)
		return -ENODEV;

	v.intval = ua;
	ret = power_supply_set_property(bat, POWER_SUPPLY_PROP_CONSTANT_CHARGE_CURRENT, &v);
	if (ret)
		pr_warn("fc: failed to set fcc=%d (%d)\n", ua, ret);

	v.intval = ctl;
	ret = power_supply_set_property(bat, POWER_SUPPLY_PROP_CHARGE_CONTROL_LIMIT, &v);
	if (ret)
		pr_warn("fc: failed to set ctl=%d (%d)\n", ctl, ret);

	return 0;
}

static int get_temp(void)
{
	union power_supply_propval v;

	if (!bat)
		return -ENODEV;

	if (power_supply_get_property(bat, POWER_SUPPLY_PROP_TEMP, &v) == 0)
		return v.intval;

	return -EINVAL;
}

static void find_bat(void)
{
	if (!bat)
		bat = power_supply_get_by_name("battery");
}

static void do_mon(struct work_struct *w)
{
	int t, ua, ctl;

	mutex_lock(&lock);

	find_bat();

	if (!enabled || !bat) {
		mutex_unlock(&lock);
		schedule_delayed_work(&mon_wq, msecs_to_jiffies(2000));
		return;
	}

	t = get_temp();
	if (t < 0) {
		mutex_unlock(&lock);
		schedule_delayed_work(&mon_wq, msecs_to_jiffies(1000));
		return;
	}

	if (t >= temp_safe) {
		if (!stopped)
			pr_info("fc: safety stop at %d.%dC\n", t / 10, t % 10);
		stopped = true;
		mutex_unlock(&lock);
		schedule_delayed_work(&mon_wq, msecs_to_jiffies(10000));
		return;
	}

	if (stopped && t < 380) {
		pr_info("fc: resume at %d.%dC\n", t / 10, t % 10);
		stopped = false;
	}

	if (stopped) {
		mutex_unlock(&lock);
		schedule_delayed_work(&mon_wq, msecs_to_jiffies(10000));
		return;
	}

	if (t >= temp_limit) {
		int p = 100 - (t - temp_limit) * 100 / (temp_safe - temp_limit);

		ua = max(fcc * p / 100, 1000000);
		ctl = max(ctl_max * p / 100, 1);
	} else {
		ua = fcc;
		ctl = ctl_max;
	}

	set_limits(ua, ctl);

	mutex_unlock(&lock);
	schedule_delayed_work(&mon_wq, msecs_to_jiffies(500));
}

static ssize_t enabled_show(struct device *dev,
			    struct device_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", enabled);
}

static ssize_t enabled_store(struct device *dev,
			     struct device_attribute *attr,
			     const char *buf, size_t count)
{
	int v;
	bool now_enabled;

	if (kstrtoint(buf, 10, &v) < 0)
		return -EINVAL;

	mutex_lock(&lock);
	enabled = v ? 1 : 0;
	now_enabled = enabled;
	if (now_enabled) {
		stopped = false;
		set_limits(fcc, ctl_max);
	}
	mutex_unlock(&lock);

	if (now_enabled)
		schedule_delayed_work(&mon_wq, msecs_to_jiffies(500));
	else
		cancel_delayed_work_sync(&mon_wq);

	return count;
}
static DEVICE_ATTR_RW(enabled);

static ssize_t fcc_show(struct device *dev,
			struct device_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", fcc);
}

static ssize_t fcc_store(struct device *dev,
			 struct device_attribute *attr,
			 const char *buf, size_t count)
{
	int v;

	if (kstrtoint(buf, 10, &v) < 0)
		return -EINVAL;
	if (v < 500000 || v > 10000000)
		return -EINVAL;

	mutex_lock(&lock);
	fcc = v;
	if (enabled && !stopped)
		set_limits(fcc, ctl_max);
	mutex_unlock(&lock);

	return count;
}
static DEVICE_ATTR_RW(fcc);

static ssize_t temp_limit_show(struct device *dev,
			       struct device_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", temp_limit);
}

static ssize_t temp_limit_store(struct device *dev,
				struct device_attribute *attr,
				const char *buf, size_t count)
{
	int v;

	if (kstrtoint(buf, 10, &v) < 0)
		return -EINVAL;
	if (v < 300 || v > 500)
		return -EINVAL;

	mutex_lock(&lock);
	temp_limit = v;
	mutex_unlock(&lock);

	return count;
}
static DEVICE_ATTR_RW(temp_limit);

static struct attribute *attrs[] = {
	&dev_attr_enabled.attr,
	&dev_attr_fcc.attr,
	&dev_attr_temp_limit.attr,
	NULL,
};

static struct attribute_group attr_group = {
	.attrs = attrs,
};

static void do_init(struct work_struct *w)
{
	struct device *dev;
	int ret, i;

	for (i = 0; i < 30; i++) {
		bat = power_supply_get_by_name("battery");
		if (bat)
			break;
		msleep(1000);
	}

	if (!bat) {
		pr_err("fc: battery not found\n");
		schedule_delayed_work(&init_wq, msecs_to_jiffies(30000));
		return;
	}

	dev = &bat->dev;
	ret = sysfs_create_group(&dev->kobj, &attr_group);
	if (ret) {
		pr_err("fc: sysfs failed\n");
		power_supply_put(bat);
		bat = NULL;
		return;
	}

	INIT_DELAYED_WORK(&mon_wq, do_mon);
	ready = true;

	if (enabled) {
		msleep(3000);
		mutex_lock(&lock);
		set_limits(fcc, ctl_max);
		mutex_unlock(&lock);
		schedule_delayed_work(&mon_wq, msecs_to_jiffies(500));
	}

	pr_info("fc: ready (fcc=%d ctl=%d)\n", fcc, ctl_max);
}

static int __init fc_init(void)
{
	INIT_DELAYED_WORK(&init_wq, do_init);
	schedule_delayed_work(&init_wq, msecs_to_jiffies(10000));
	pr_info("fc: loading...\n");
	return 0;
}

static void __exit fc_exit(void)
{
	cancel_delayed_work_sync(&mon_wq);
	cancel_delayed_work_sync(&init_wq);

	mutex_lock(&lock);
	if (ready && bat) {
		sysfs_remove_group(&bat->dev.kobj, &attr_group);
		power_supply_put(bat);
		bat = NULL;
		ready = false;
	}
	mutex_unlock(&lock);
}

module_init(fc_init);
module_exit(fc_exit);

MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("Fast charger control for GKI 5.10 kernels");
MODULE_AUTHOR("SrMatdroid");
