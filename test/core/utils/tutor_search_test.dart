import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/utils/tutor_search.dart';
void main(){
 const tutor={'full_name':'Marie','subjects':['Mathematics','Physics'],'exam_preparation':['Cameroon GCE Ordinary Level'],'city':'Douala'};
 test('aliases case and accents resolve to teaching subjects',(){for(final q in ['maths','Maths','math','mathématiques','matematics']){expect(TutorSearch.matches(tutor,q),isTrue,reason:q);}});
 test('exam and location queries use published fields',(){expect(TutorSearch.matches(tutor,'GCE O level'),isTrue);expect(TutorSearch.matches(tutor,'maths Douala'),isTrue);});
 test('minor typo is accepted but unrelated query is not',(){expect(TutorSearch.matches(tutor,'mathematis'),isTrue);expect(TutorSearch.matches(tutor,'piano'),isFalse);expect(TutorSearch.matches(tutor,'maths chemistry'),isFalse);});
}
