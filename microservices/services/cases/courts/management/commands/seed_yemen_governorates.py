"""
Management command to seed Yemeni governorates and districts
"""
from django.core.management.base import BaseCommand
from courts.models import Governorate, District


class Command(BaseCommand):
    help = 'Add all Yemeni governorates and their districts to the database'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting to add Yemeni governorates and districts...'))
        
        # Data structure: {governorate_name: [list of districts]}
        yemen_data = {
            'أمانة العاصمة صنعاء': [
                'التحرير', 'الوحدة', 'السبعين', 'معين', 'شعوب', 'الثورة', 
                'آزال', 'الصافية', 'بني الحارث', 'صنعاء القديمة', 'الروضة', 
                'المنصورة', 'النجمة', 'الزبيري', 'الضالع', 'المناخة'
            ],
            'محافظة صنعاء': [
                'همدان', 'أرحب', 'نهم', 'بني حشيش', 'سنحان', 'بلاد الروس', 
                'بني مطر', 'الحيمة الداخلية', 'الحيمة الخارجية', 'مناخة', 
                'صفعان', 'خولان', 'الطيال', 'بني ضبيان', 'الحصن', 'جحانة', 
                'بني بهلول', 'البيضاء', 'الحداء', 'المناخة'
            ],
            'محافظة عدن': [
                'صيرة', 'المعلا', 'التواهي', 'الشيخ عثمان', 'المنصورة', 
                'دار سعد', 'البريقة', 'خور مكسر', 'كريتر', 'المنظر الجميل'
            ],
            'محافظة تعز': [
                'المظفر', 'صالة', 'القاهرة', 'التعزية', 'شرعب السلام', 
                'شرعب الرونة', 'ماوية', 'سامع', 'الشمايتين', 'المواسط', 
                'المعافر', 'جبل حبشي', 'حيفان', 'الوازعية', 'مقبنة', 
                'المخا', 'ذباب', 'موزع', 'المقاطرة', 'المسيمير'
            ],
            'محافظة حضرموت': [
                'المكلا', 'الشحر', 'غيل باوزير', 'الديس الشرقية', 
                'الريدة وقصيعر', 'سيئون', 'تريم', 'شبام', 'القطن', 
                'حورة ووادي العين', 'عمد', 'رخية', 'دوعن', 'يبعث', 
                'الضليعة', 'حجر', 'بروم ميفع', 'أرياف المكلا', 'السوم', 
                'ثمود', 'هود', 'قشن', 'القطن', 'الريدة'
            ],
            'محافظة الحديدة': [
                'الحديدة', 'الميناء', 'الحالي', 'الحوك', 'باجل', 
                'المراوعة', 'الزيدية', 'الضحي', 'القناوص', 'الزهرة', 
                'اللحية', 'كمران', 'الصليف', 'حيس', 'الخوخة', 
                'التحيتا', 'الجراحي', 'زبيد', 'بيت الفقيه', 'المنصورية', 
                'الدريهمي', 'السخنة', 'جبل رأس', 'برع', 'المراوعة'
            ],
            'محافظة إب': [
                'إب', 'الظهار', 'المشنة', 'السبرة', 'السدة', 'النادرة', 
                'يريم', 'القفر', 'حبيش', 'المخادر', 'العدين', 'فرع العدين', 
                'حزم العدين', 'بعدان', 'جبلة', 'ذي السفال', 'الرضمة', 
                'السياني', 'العرش', 'الفرع', 'الرضمة'
            ],
            'محافظة شبوة': [
                'عتق', 'بيحان', 'عسيلان', 'عين', 'نصاب', 'حبان', 
                'الروضة', 'ميفعة', 'رضوم', 'جردان', 'الطلح', 
                'مرخة العليا', 'مرخة السفلى', 'الصعيد', 'حطيب', 
                'عرماء', 'دهير', 'الروضة', 'المصينعة'
            ],
            'محافظة مأرب': [
                'مأرب', 'صرواح', 'مجزر', 'رغوان', 'مدغل', 'الجوبة', 
                'حريب', 'العبدية', 'ماهلية', 'رحبة', 'حريب القراميش', 
                'بدبدة', 'الجوبة', 'صرواح'
            ],
            'محافظة الجوف': [
                'الحزم', 'خب والشعف', 'برط العنان', 'الخلق', 'الحميدات', 
                'الزاهر', 'الغيل', 'المطمة', 'المصلوب', 'المتون', 
                'خراب المراشي', 'رجوزة', 'الغيل', 'المطمة'
            ],
            'محافظة المهرة': [
                'الغيضة', 'حوف', 'شحن', 'سيحوت', 'قشن', 'حصوين', 
                'المسيلة', 'منعر', 'حات', 'زمخ ومنوخ', 'الغيضة', 
                'شحن', 'سيحوت'
            ],
            'محافظة البيضاء': [
                'البيضاء', 'الزاهر', 'الصومعة', 'ذي ناعم', 'ناطع', 
                'نعمان', 'الملاجم', 'رداع', 'الشرية', 'الرياشية', 
                'القريشية', 'ولد ربيع', 'السوادية', 'مكيراس', 'الطفة', 
                'مسورة', 'الزاهر', 'الصومعة'
            ],
            'محافظة لحج': [
                'الحوطة', 'تبن', 'طور الباحة', 'المضاربة ورأس العارة', 
                'الملاح', 'المسيمير', 'القبيطة', 'حالمين', 'حيفان', 
                'المقاطرة', 'يافع', 'يهر', 'الحد', 'ردفان', 'الحوطة', 
                'تبن', 'طور الباحة'
            ],
            'محافظة ذمار': [
                'ذمار', 'عنس', 'جهران', 'ميفعة عنس', 'عتمة', 'الحداء', 
                'مغرب عنس', 'وصاب العالي', 'وصاب السافل', 'ضوران آنس', 
                'جبل الشرق', 'المنار', 'عنس', 'جهران'
            ],
            'محافظة صعدة': [
                'صعدة', 'سحار', 'الصفراء', 'مجز', 'باقم', 'رازح', 
                'غمر', 'منبه', 'شدا', 'حيدان', 'ساقين', 'كتاف والبقع', 
                'الحشوة', 'آل سالم', 'قطابر', 'سحار', 'الصفراء'
            ],
            'محافظة حجة': [
                'حجة', 'عبس', 'حيران', 'ميدي', 'حرض', 'بكيل المير', 
                'مستبأ', 'كشر', 'قفل شمر', 'المحابشة', 'الشاهل', 
                'كعيدنة', 'أفلح الشام', 'أفلح اليمن', 'المغربة', 
                'بني قيس', 'الشغادرة', 'أسلم', 'خيران المحرق', 
                'خيران المعافا', 'بني العوام', 'الجميمة', 'كحلان الشرف', 
                'كحلان عفار', 'كحلان عاهم', 'عبس', 'حيران'
            ],
            'محافظة المحويت': [
                'المحويت', 'شبام كوكبان', 'الطويل', 'ملحان', 'الخبت', 
                'بني سعد', 'الرجم', 'حفاش', 'شبام حراز', 'الخبت', 
                'بني سعد', 'الرجم'
            ],
            'محافظة ريمة': [
                'الجبين', 'مزهر', 'السلفية', 'بلاد الطعام', 'الجعفرية', 
                'العدين', 'كسمة', 'الجبين', 'مزهر', 'السلفية'
            ],
            'محافظة الضالع': [
                'الضالع', 'جبن', 'الحشاء', 'الظاهر', 'المنصورة', 
                'الملاح', 'المسيمير', 'القبيطة', 'حالمين', 'حيفان', 
                'المقاطرة', 'يافع', 'يهر', 'الحد', 'ردفان', 'جبن', 
                'الحشاء', 'الظاهر'
            ],
            'محافظة عمران': [
                'عمران', 'ريدة', 'حوث', 'خارف', 'شهارة', 'السودة', 
                'بني صريم', 'السود', 'مسور', 'حرف سفيان', 'جبل عيال يزيد', 
                'ريدة', 'حوث', 'خارف'
            ],
            'محافظة سقطرى': [
                'حديبو', 'قلنسية وعبد الكوري', 'سمحة', 'دكسم', 'قاضب'
            ],
        }
        
        created_count = 0
        updated_count = 0
        districts_created = 0
        
        for gov_name, districts in yemen_data.items():
            # Create or get governorate
            governorate, created = Governorate.objects.get_or_create(
                name=gov_name,
                defaults={'name': gov_name}
            )
            
            if created:
                created_count += 1
                self.stdout.write(self.style.SUCCESS(f'✓ Created governorate: {gov_name}'))
            else:
                updated_count += 1
                self.stdout.write(self.style.WARNING(f'→ Governorate already exists: {gov_name}'))
            
            # Create districts for this governorate (remove duplicates)
            unique_districts = list(set(districts))  # Remove duplicates
            for district_name in unique_districts:
                district, created = District.objects.get_or_create(
                    governorate=governorate,
                    name=district_name,
                    defaults={'governorate': governorate, 'name': district_name}
                )
                
                if created:
                    districts_created += 1
                    self.stdout.write(self.style.SUCCESS(f'  ✓ Created district: {district_name}'))
                else:
                    self.stdout.write(self.style.WARNING(f'  → District already exists: {district_name}'))
        
        # Summary
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('=' * 60))
        self.stdout.write(self.style.SUCCESS('Summary:'))
        self.stdout.write(self.style.SUCCESS(f'  - Governorates created: {created_count}'))
        self.stdout.write(self.style.SUCCESS(f'  - Governorates already existed: {updated_count}'))
        self.stdout.write(self.style.SUCCESS(f'  - Districts created: {districts_created}'))
        self.stdout.write(self.style.SUCCESS(f'  - Total governorates: {Governorate.objects.count()}'))
        self.stdout.write(self.style.SUCCESS(f'  - Total districts: {District.objects.count()}'))
        self.stdout.write(self.style.SUCCESS('=' * 60))
        self.stdout.write(self.style.SUCCESS('✓ Successfully added all Yemeni governorates and districts!'))

