import 'package:geocoder/geocoder.dart';
import 'package:keepaustinblack/main_screens/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:searchable_dropdown/searchable_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../directory_stream.dart';
import 'package:geolocator/geolocator.dart';

class MainFeed extends StatefulWidget {
  static String id = 'mainFeed';
  static Position location;
  static Map<String, double> distances = {};

  @override
  _MainFeedState createState() => _MainFeedState();
}

class _MainFeedState extends State<MainFeed> {
  String category;
  bool isFavoritesList = false;
  String uid, searchTxt = "";
  List<DropdownMenuItem> categoriesList;

  Future<String> getUid() async {
    FirebaseUser currUser = await FirebaseAuth.instance.currentUser();
    if (currUser == null) {
      print('not logged in');
      return null;
    }
    uid = currUser.uid;
    return uid;
  }

  Future<Position> getCurrentLocation() async {
    GeolocationStatus status =
        await Geolocator().checkGeolocationPermissionStatus();

    if (status != GeolocationStatus.disabled) {
      Position pos = await Geolocator()
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      print(pos.toString());
      return pos;
    } else {
      return null;
    }
  }

  void mapOutdistances() async {
    MainFeed.location = await getCurrentLocation();
    Firestore store = Firestore.instance;
    for (String category in categories) {
      print(category);
      QuerySnapshot listingsStream =
          await store.collection(category).getDocuments();

      List<DocumentSnapshot> listings = listingsStream.documents;
      for (DocumentSnapshot listing in listings) {
        DocumentReference business = listing.reference;
        String name = listing.data['Business'];
        double long = listing.data['longitude'];
        double lat = listing.data['latitude'];
        if (long != 0 && long != null && lat != 0 && lat != null) {
          try {
            while (MainFeed.location == null) {}
            ;
            double distance = await Geolocator().distanceBetween(lat, long,
                MainFeed.location.latitude, MainFeed.location.longitude);
            MainFeed.distances.addAll({name: distance});
          } on Exception catch (e) {
            print("ERROR: $name --- ${e.toString()}");
          }
        }
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setCurrCategory();
//    mapOutdistances();

    //initialize the list of categories in the category picker
    categoriesList = categories.map<DropdownMenuItem<String>>((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value),
      );
    }).toList();
  }

  //method check for cached last chosen category
  void setCurrCategory() async {
    uid = await getUid();
    final prefs = await SharedPreferences.getInstance();
    String lastCategory = prefs.getString('currCategory') ?? null;
    //if there is already a cached category, go to that category
    if (lastCategory != null) {
      setState(() {
        category = lastCategory;
      });
    }
    //if there was no previous set current category, set it
    else {
      prefs.setString('currCategory', categories[0]);
      setState(() {
        category = categories[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              margin: EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: SearchableDropdown.single(
                  isExpanded: true,
                  items: categoriesList,
                  onChanged: (value) async {
                    setState(() {
                      category = value;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    prefs.setString('currCategory', value);
                  },
                  value: category,
                  menuBackgroundColor: Colors.white,
                  displayClearIcon: false,
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            TextField(),
            if (!isFavoritesList)
              DirectoryStream(
                firestore: Firestore.instance,
                category: category,
                type: 'directory',
                uid: uid,
                search: searchTxt,
              ),
            if (isFavoritesList)
              DirectoryStream(
                firestore: Firestore.instance,
                category: category,
                uid: uid,
                type: 'favorites',
                search: searchTxt,
              ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('Keep Austin Black'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: <Widget>[
                Switch(
                  value: isFavoritesList,
                  onChanged: (value) {
                    if (uid == null) {
                      Alert(
                        title: 'Not Signed In',
                        context: context,
                        desc:
                            "You may browse the business listings as a guest, but in order to save your favorite business you must sign in.",
                        buttons: [
                          DialogButton(
                            child: Text(
                              "Sign In",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20),
                            ),
                            onPressed: () => Navigator.pushReplacementNamed(
                                context, LoginPage.id),
                            width: 60,
                          ),
                          DialogButton(
                            child: Text(
                              "Cancel",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20),
                            ),
                            onPressed: () => Navigator.pop(context),
                            width: 60,
                          )
                        ],
                      ).show();
                      return;
                    }
                    print(value.toString());
                    setState(() {
                      isFavoritesList = value;
                    });
                  },
                  inactiveThumbColor: Colors.white,
                  activeColor: Colors.white,
                ),
                Icon(isFavoritesList ? Icons.favorite : Icons.favorite_border),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'Sign Out!':
                        FirebaseAuth.instance.signOut();
                        Navigator.pushReplacementNamed(context, LoginPage.id);
                        break;
                      case 'Sign In!':
                        Navigator.pushReplacementNamed(context, LoginPage.id);
                        break;
                      case 'Submit Business':
                        launch(
                            "https://docs.google.com/forms/d/e/1FAIpQLSd6P1mSVRi7FvgUr2T3BQ0rDSuluPucbxvP543R7DsZDO6dnQ/viewform");
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    String text = uid == null ? 'Sign In!' : 'Sign Out!';
                    return {text, 'Submit Business'}.map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice),
                      );
                    }).toList();
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
