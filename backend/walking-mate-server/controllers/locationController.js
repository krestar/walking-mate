const axios = require("axios");

exports.getAddressFromCoords = async (req, res) => {
  const { lat, lng } = req.body;

  if (!lat || !lng) {
    return res
      .status(400)
      .json({ message: "위도(lat)와 경도(lng)는 필수입니다." });
  }

  const naverClientId = process.env.NAVER_CLIENT_ID;
  const naverClientSecret = process.env.NAVER_CLIENT_SECRET;
  const coords = `${lng},${lat}`;

  const apiUrl = new URL(
    "https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc"
  );
  apiUrl.searchParams.append("coords", coords);
  apiUrl.searchParams.append("output", "json");
  apiUrl.searchParams.append("orders", "roadaddr,addr");

  try {
    const response = await axios.get(apiUrl.href, {
      headers: {
        "X-NCP-APIGW-API-KEY-ID": naverClientId,
        "X-NCP-APIGW-API-KEY": naverClientSecret,
      },
    });

    if (response.data.status.code === 0 && response.data.results.length > 0) {
      const roadAddr = response.data.results.find(r => r.name === 'roadaddr');
      const jibunAddr = response.data.results.find(r => r.name === 'addr');
      
      let finalAddress = "주소 정보를 찾을 수 없습니다.";

      if (roadAddr && roadAddr.land) {
        const region = roadAddr.region;
        const land = roadAddr.land;
        finalAddress = [
          region.area1?.name,
          region.area2?.name,
          land.name,
          land.number1,
          land.addition0?.value,
        ].filter(Boolean).join(" ");
      } else if (jibunAddr) {
        const region = jibunAddr.region;
        const land = jibunAddr.land;
        finalAddress = [
          region.area1?.name,
          region.area2?.name,
          region.area3?.name,
          land?.number1,
          land?.number2,
        ].filter(Boolean).join(" ");
      }

      res.status(200).json({ address: finalAddress.trim() });

    } else {
      res.status(404).json({ message: "해당 좌표의 주소를 찾을 수 없습니다." });
    }
  } catch (error) {
    if (error.response) {
      console.error("Reverse Geocoding Error:", JSON.stringify(error.response.data, null, 2));
    }
    res.status(500).json({ message: "주소 변환 중 서버 오류가 발생했습니다." });
  }
};