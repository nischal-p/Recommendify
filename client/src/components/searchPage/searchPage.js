import React, { useState } from "react";
import SearchResultsRow from "./searchResultsRow";
import "../../style/searchPage.css";
import PageNavbar from "../pagenavbar/PageNavbar";

const SearchPage = () => {
    const [artistOrTrack, setArtistOrTrack] = useState("Search by Track");

    const [searchParameter, setSearchParameter] = useState("");

    // state for results
    const [results, setResults] = useState([]);

    const handleChange = (event) => {
        setSearchParameter(event.target.value);
    };

    const onCheck = () => {
        if (artistOrTrack === "Search by Track") {
            setArtistOrTrack("Search by Artist");
        } else {
            setArtistOrTrack("Search by Track");
        }

        setResults([])
    };

    const handleSubmit = (event) => {
        event.preventDefault();

        // check which parameter is selected
        if (artistOrTrack === "Search by Track") {
            fetch("http://localhost:8081/search/" + searchParameter, {
                method: "get",
                headers: { "Content-Type": "application/json" },
            })
                .then((response) => response.json())
                .then((res) => {
                    setResults(res);

                    console.log(res);
                });
        } else {
            fetch("http://localhost:8081/search/artist/" + searchParameter, {
                method: "get",
                headers: { "Content-Type": "application/json" },
            })
                .then((response) => response.json())
                .then((res) => {
                    // set internal state
                    setResults(res);
                });
        }
    };

    return (
        <div className="search-page">
            <PageNavbar active="search" />
            <div className="container SearchResults-container">
                <div>
                    <form className="search-bar" onSubmit={handleSubmit}>
                        <input
                            className="search-input"
                            placeholder={artistOrTrack}
                            onChange={handleChange}
                        />
                        <div class="artists-tracks">
                            <label class="checkbox-label">
                                <span>Tracks</span>
                                <label className="switch">
                                    <input type="checkbox" onChange={onCheck} />
                                    <span class="slider round"></span>
                                </label>
                                <span>Artists</span>
                            </label>
                        </div>
                    </form>
                    <div className="results-container" id="results">
                        <div className="results-title">
                            <h3>Tracklist</h3>
                            <div class="total-tracks">
                                <span>{results.length} Tracks</span>
                            </div>
                        </div>
                        {results.map((obj, idx) => {
                            console.log("Passing:")
                            console.log(obj.spotify_id)
                            console.log(obj.artist_name)
                            return (
                                <SearchResultsRow
                                    key={idx}
                                    title={obj.song_name}
                                    link={obj.link}
                                    artist={obj.artist_name}
                                    img={obj.img_src}
                                    popularity={obj.popularity}
                                    danceability={obj.danceability}
                                    mood={obj.mood}
                                    song_id={obj.spotify_id}
                                    saved={false}
                                />
                            );
                        })}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default SearchPage;
